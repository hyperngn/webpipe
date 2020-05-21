defmodule WebpipeTest do
  use ExUnit.Case
  doctest Webpipe

  test "greets the world" do
    assert Webpipe.hello() == :world
  end
end
