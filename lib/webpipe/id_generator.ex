defmodule Webpipe.IDGenerator do
  def generate() do
    Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end
end
