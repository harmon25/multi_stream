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

  def upload_response() do
    """
    <div>
    Thanks for uploading!
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
