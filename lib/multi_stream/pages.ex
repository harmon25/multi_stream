defmodule MultiStream.Pages do
  def index() do
    """
    <form method="post" action="/upload" enctype="multipart/form-data">
    <label for="fname">First name:</label><br>
    <input type="text" id="fname" name="fname" value="John"><br>
    <label for="lname">Last name:</label><br>
    <input type="text" id="lname" name="lname" value="Doe"><br>
    <label for="file">File</label><br>
    <input multiple="true" type="file" id="file" name="file">
    <br><br>
    <input type="submit" value="Submit">
    </form>
    """
    |> layout()
  end

  def upload_response(%{adapter: %MultiStream.Adapters.S3{}} = file) do
    {:ok, presigned_url} =
      ExAws.Config.new(:s3)
      |> ExAws.S3.presigned_url(:get, "multi-upload-demo-25", file.adapter.key)

    """
    <div>
    Thanks for uploading!
    <a target="_blank" href="#{presigned_url}">#{file.filename}</a>
    </div>
    """
    |> layout()
  end

  def upload_response(file) do
    # {:ok, presigned_url} =
    #   ExAws.Config.new(:s3)
    #   |> ExAws.S3.presigned_url(:get, "multi-upload-demo-25", file.adapter.key)
    """
    <div>
    Thanks for uploading!
    <a target="_blank" href="/download/?filename=#{file.filename}">#{file.filename}</a>
    </div>
    """
    |> layout()
  end

  defp layout(content) do
    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>MultiPart Stream</title>

    </head>

    <body>
      #{content}
    </body>
    </html>

    """
  end
end
