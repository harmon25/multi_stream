defmodule MultiStream.Router do
  use Plug.Router
  use Plug.ErrorHandler
  plug(Plug.Logger)

  # plug(Plug.Debugger)

  plug(:match)

  plug(Plug.Parsers,
    parsers: [
      {
        MultiStream,
        # encryption: {:aes_256_cbc, <<1::256>>}
        # adapter_opts: [],
        adapter_opts: [bucket: "multi-upload-demo-25", upload_prefix: "upload"],
        adapter: MultiStream.Adapters.S3
      },
      :urlencoded,
      :json
    ],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/" do
    put_resp_content_type(conn, "text/html")
    |> send_resp(200, MultiStream.Pages.index())
  end

  post "/upload" do
    IO.inspect(conn)

    # Stream.into(, File.stream!(conn.params["file"].filename))
    # |>

    put_resp_content_type(conn, "text/html")
    |> send_resp(200, MultiStream.Pages.upload_response(conn.params["file"]))
  end

  get "/download" do
    # {:ok, presigned_url} =
    #   ExAws.Config.new(:s3)
    #   |> ExAws.S3.presigned_url(:get, "multi-upload-demo-25", conn.params["object_key"])

    put_resp_content_type(conn, "text/html")
    |> send_resp(200, "OK")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  def handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack} = err) do
    IO.inspect(err)
    send_resp(conn, conn.status, "Something went wrong")
  end
end
