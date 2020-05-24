defmodule Webpipe.Server do
  use GenServer
  require Logger

  alias Webpipe.Router

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @hour 60 * 60 * 1000
  @impl GenServer
  def init(opts) do
    port = opts[:port] || 8080
    Logger.info("Starting HTTP Server at http://localhost:#{port}/")

    :cowboy.start_clear(:http, [port: port], %{
      env: %{dispatch: Router.routes()},
      idle_timeout: @hour,
      inactivity_timeout: @hour,
      request_timeout: @hour
    })

    {:ok, :state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :cowboy.stop_listener(:http)
  end
end
