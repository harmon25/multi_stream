defmodule MultiStream.Router do
  use Plug.Router
  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [
      {MultiStream, bucket: "multi-upload-demo-25", upload_prefix: "upload", hash_algo: :blake2s},
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

    put_resp_content_type(conn, "text/html")
    |> send_resp(200, MultiStream.Pages.upload_response())
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
