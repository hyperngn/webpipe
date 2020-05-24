defmodule Webpipe.SessionStore do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :state)
  end

  @impl GenServer
  def init(_opts) do
    # {"foo" => [#<PID1>, #<PID2>], "bar"....}
    :ets.new(:sessions, [:named_table, :public, :bag])
    {:ok, :state}
  end

  def get_listeners(session_id) do
    :ets.lookup(:sessions, session_id)
    |> Enum.map(fn {_id, pid} -> pid end)
  end

  def register_listener(session_id) do
    :ets.insert(:sessions, {session_id, self()})
  end
end
