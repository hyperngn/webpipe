defmodule Webpipe.Assets do
  @assets :code.priv_dir(:webpipe) |> Path.join("assets/*") |> Path.wildcard()

  for asset <- @assets do
    asset_name = asset |> Path.basename()
    asset_contents = File.read!(asset)
    mime_type = MIME.from_path(asset)

    @external_resource asset_name
    def for_path(unquote(asset_name)), do: {unquote(mime_type), unquote(asset_contents)}
  end

  def for_path(_), do: {"text/html", "<!doctype html><h1>404. Resource not found.</h1>"}
end
