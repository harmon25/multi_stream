defmodule MultiStream do
  @moduledoc """
  Parses multipart request body.
  ## Options
  All options supported by `Plug.Conn.read_body/2` are also supported here.
  They are repeated here for convenience:
    * `:length` - sets the maximum number of bytes to read from the request,
      defaults to 8_000_000 bytes. Unlike `Plug.Conn.read_body/2` supports
      passing an MFA (`{module, function, args}`) which will be evaluated
      on every request to determine the value.
    * `:read_length` - sets the amount of bytes to read at one time from the
      underlying socket to fill the chunk, defaults to 1_000_000 bytes
    * `:read_timeout` - sets the timeout for each socket read, defaults to
      15_000ms
  So by default, `Plug.Parsers` will read 1_000_000 bytes at a time from the
  socket with an overall limit of 8_000_000 bytes.
  Besides the options supported by `Plug.Conn.read_body/2`, the multipart parser
  also checks for:
    * `:headers` - containing the same `:length`, `:read_length`
      and `:read_timeout` options which are used explicitly for parsing multipart
      headers.
    * `:include_unnamed_parts_at` - string specifying a body parameter that can
      hold a lists of body parts that didn't have a 'Content-Disposition' header.
      For instance, `include_unnamed_parts_at: "_parts"` would result in
      a body parameter `"_parts"`, containing a list of parts, each with `:body`
      and `:headers` fields, like `[%{body: "{}", headers: [{"content-type", "application/json"}]}]`.
  * `:validate_utf8` - specifies whether multipart body parts should be validated
      as utf8 binaries. Defaults to true.
  """

  @behaviour Plug.Parsers

  require Logger

  def init(opts) do
    Logger.info("Initalized multi with opts #{inspect(opts)}")

    # Remove the length from options as it would attempt
    # to eagerly read the body on the limit value.
    {limit, opts} = Keyword.pop(opts, :length, 8_000_000_000)

    # The read length is now our effective length per call.
    {read_length, opts} = Keyword.pop(opts, :read_length, 5_242_880)
    opts = [length: read_length, read_length: read_length] ++ opts

    # The header options are handled individually.
    {headers_opts, opts} = Keyword.pop(opts, :headers, [])

    {limit, headers_opts, opts}
  end

  def parse(conn, "multipart", subtype, _headers, opts_tuple)
      when subtype in ["form-data", "mixed"] do
    try do
      parse_multipart(conn, opts_tuple)
    rescue
      # Do not ignore upload errors
      e in [Plug.UploadError, Plug.Parsers.BadEncodingError] ->
        reraise e, __STACKTRACE__

      # All others are wrapped
      e ->
        reraise Plug.Parsers.ParseError.exception(exception: e), __STACKTRACE__
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  ## Multipart

  defp parse_multipart(conn, {{module, fun, args}, header_opts, opts}) do
    limit = apply(module, fun, args)
    parse_multipart(conn, {limit, header_opts, opts})
  end

  defp parse_multipart(conn, {limit, headers_opts, opts}) do
    read_result = Plug.Conn.read_part_headers(conn, headers_opts)
    {:ok, limit, acc, conn} = parse_multipart(read_result, limit, opts, headers_opts, [])

    if limit > 0 do
      {:ok, Enum.reduce(acc, %{}, &Plug.Conn.Query.decode_pair/2), conn}
    else
      {:error, :too_large, conn}
    end
  end

  defp parse_multipart({:ok, headers, conn}, limit, opts, headers_opts, acc) when limit >= 0 do
    {conn, limit, acc} = parse_multipart_headers(headers, conn, limit, opts, acc)
    read_result = Plug.Conn.read_part_headers(conn, headers_opts)
    parse_multipart(read_result, limit, opts, headers_opts, acc)
  end

  defp parse_multipart({:ok, _headers, conn}, limit, _opts, _headers_opts, acc) do
    {:ok, limit, acc, conn}
  end

  defp parse_multipart({:done, conn}, limit, _opts, _headers_opts, acc) do
    {:ok, limit, acc, conn}
  end

  defp parse_multipart_headers(headers, conn, limit, opts, acc) do
    case multipart_type(headers, opts) do
      {:binary, name} ->
        {:ok, limit, body, conn} =
          parse_multipart_body(Plug.Conn.read_part_body(conn, opts), limit, opts, "")

        if Keyword.get(opts, :validate_utf8, true) do
          Plug.Conn.Utils.validate_utf8!(body, Plug.Parsers.BadEncodingError, "multipart body")
        end

        {conn, limit, [{name, body} | acc]}

      {:part, name} ->
        {:ok, limit, body, conn} =
          parse_multipart_body(Plug.Conn.read_part_body(conn, opts), limit, opts, "")

        {conn, limit, [{name, %{headers: headers, body: body}} | acc]}

      {:file, name, %MultiStream.Upload{} = uploaded} ->
        uploaded = start_upload(uploaded, opts)

        {:ok, limit, conn, uploaded} =
          parse_multipart_file(Plug.Conn.read_part_body(conn, opts), limit, opts, uploaded)

        uploaded = finish_upload(uploaded)

        {conn, limit, [{name, uploaded} | acc]}

      :skip ->
        {conn, limit, acc}
    end
  end

  defp parse_multipart_body({:more, tail, conn}, limit, opts, body)
       when limit >= byte_size(tail) do
    read_result = Plug.Conn.read_part_body(conn, opts)
    parse_multipart_body(read_result, limit - byte_size(tail), opts, body <> tail)
  end

  defp parse_multipart_body({:more, tail, conn}, limit, _opts, body) do
    {:ok, limit - byte_size(tail), body, conn}
  end

  defp parse_multipart_body({:ok, tail, conn}, limit, _opts, body)
       when limit >= byte_size(tail) do
    {:ok, limit - byte_size(tail), body <> tail, conn}
  end

  defp parse_multipart_body({:ok, tail, conn}, limit, _opts, body) do
    {:ok, limit - byte_size(tail), body, conn}
  end

  defp parse_multipart_file({:more, tail, conn}, limit, opts, uploaded)
       when limit >= byte_size(tail) do
    chunk_size = byte_size(tail)

    uploaded = set_upload_id(uploaded) |> upload_part(chunk_size, tail)

    read_result = Plug.Conn.read_part_body(conn, opts)

    parse_multipart_file(read_result, limit - chunk_size, opts, uploaded)
  end

  defp parse_multipart_file({:more, tail, conn}, limit, _opts, uploaded) do
    {:ok, limit - byte_size(tail), conn, uploaded}
  end

  defp parse_multipart_file({:ok, tail, conn}, limit, _opts, uploaded)
       when limit >= byte_size(tail) do
    # when the chunk is <= 5MB just upload with single s3 upload.
    chunk_size = byte_size(tail)

    uploaded = upload_part(uploaded, chunk_size, tail)

    {:ok, limit - chunk_size, conn, uploaded}
  end

  defp parse_multipart_file({:ok, tail, conn}, limit, _opts, uploaded) do
    {:ok, limit - byte_size(tail), conn, uploaded}
  end

  ## Helpers

  defp multipart_type(headers, opts) do
    if disposition = get_header(headers, "content-disposition") do
      multipart_type_from_disposition(headers, disposition, opts)
    else
      multipart_type_from_unnamed(opts)
    end
  end

  defp multipart_type_from_unnamed(opts) do
    case Keyword.fetch(opts, :include_unnamed_parts_at) do
      {:ok, name} when is_binary(name) -> {:part, name <> "[]"}
      :error -> :skip
    end
  end

  defp multipart_type_from_disposition(headers, disposition, opts) do
    with [_, params] <- :binary.split(disposition, ";"),
         %{"name" => name} = params <- Plug.Conn.Utils.params(params) do
      handle_disposition(params, name, headers, opts)
    else
      _ -> :skip
    end
  end

  defp handle_disposition(params, name, headers, opts) do
    case params do
      %{"filename" => ""} ->
        :skip

      %{"filename" => filename} ->
        content_type = get_header(headers, "content-type")
        # alternative to plug upload struct
        {:file, name, create_new_upload(filename, content_type, opts)}

      %{"filename*" => ""} ->
        :skip

      %{"filename*" => "utf-8''" <> filename} ->
        filename = URI.decode(filename)

        Plug.Conn.Utils.validate_utf8!(
          filename,
          Plug.Parsers.BadEncodingError,
          "multipart filename"
        )

        content_type = get_header(headers, "content-type")

        {:file, name, create_new_upload(filename, content_type, opts)}

      %{} ->
        {:binary, name}
    end
  end

  defp create_new_upload(filename, content_type, opts) do
    %MultiStream.Upload{
      filename: filename,
      content_type: content_type,
      key: gen_key(opts),
      bucket: opts[:bucket]
    }
  end

  defp get_header(headers, key) do
    case List.keyfind(headers, key, 0) do
      {^key, value} -> value
      nil -> nil
    end
  end

  defp encode_hash(hash) do
    :crypto.hash_final(hash)
    |> Base.encode16()
  end

  defp finish_upload(%{upload_id: nil} = uploaded) do
    %{uploaded | hash: encode_hash(uploaded.hash)}
  end

  defp finish_upload(%{upload_id: upload_id} = uploaded) do
    reversed_parts = Enum.map(uploaded.parts, &Task.await/1) |> Enum.reverse()

    ExAws.S3.complete_multipart_upload(
      uploaded.bucket,
      uploaded.key,
      upload_id,
      reversed_parts
    )
    |> ExAws.request!()

    %{uploaded | hash: encode_hash(uploaded.hash), parts: reversed_parts}
  end

  defp start_upload(uploaded, opts) do
    %{uploaded | hash: :crypto.hash_init(opts[:hash_algo])}
  end

  # used to start a new multipart upload, or just return existing upload_id
  defp set_upload_id(%{upload_id: nil} = uploaded) do
    %{body: %{upload_id: upload_id}} =
      ExAws.S3.initiate_multipart_upload(uploaded.bucket, uploaded.key) |> ExAws.request!()

    %{uploaded | upload_id: upload_id}
  end

  defp set_upload_id(uploaded), do: uploaded

  defp gen_key(opts) do
    prefix = Keyword.get(opts, :upload_prefix, "upload")
    key_generator = Keyword.get(opts, :key_generator, &default_key_generator/0)

    Path.join([prefix, key_generator.()])
  end

  defp default_key_generator() do
    :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 32)
  end

  # if upload_id is nil and parts_count: 0 the file is under 5 mb so just upload it in one request.
  defp upload_part(%MultiStream.Upload{upload_id: nil, parts_count: 0} = uploaded, size, body) do
    ExAws.S3.put_object(uploaded.bucket, uploaded.key, body)
    |> ExAws.request!()

    %{
      uploaded
      | length: size + uploaded.length,
        hash: :crypto.hash_update(uploaded.hash, body)
    }
  end

  defp upload_part(%MultiStream.Upload{} = uploaded, size, body) do
    parts_count = uploaded.parts_count + 1

    new_part_async = upload_async(uploaded, parts_count, body)

    %{
      uploaded
      | length: size + uploaded.length,
        hash: :crypto.hash_update(uploaded.hash, body),
        parts_count: parts_count,
        parts: [new_part_async | uploaded.parts]
    }
  end

  # launches async task to upload this part.
  defp upload_async(uploaded, parts_count, body) do
    Task.async(fn ->
      %{headers: headers} =
        ExAws.S3.upload_part(
          uploaded.bucket,
          uploaded.key,
          uploaded.upload_id,
          parts_count,
          body
        )
        |> ExAws.request!()

      {parts_count, get_header(headers, "ETag")}
    end)
  end
end
