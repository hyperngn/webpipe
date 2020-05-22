defmodule Webpipe do
  defmodule HTTPHandler do
    import Logger, only: [info: 1]

    def init(req, _opts) do
      info [req.method, " ", req.path, " PID:", inspect(self())]

      case {req.method, req.path} do
        {"GET", "/"} ->
          index_page(req)

        {"GET", "/session-sse/" <> id} ->
          session_eventsource_handler(id, req)

        {method, "/session/" <> id} when method in ~w[GET PUT POST PATCH] ->
          session_handler(method, id, req)

        {method, path} ->
          not_found(method, path, req)
      end
    end

    def index_page(req) do
      resp =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/html; charset=utf-8"},
          render_page("index.html"),
          req
        )

      {:ok, resp, []}
    end

    # TODO: this is inefficient fix it
    defp render_page(name, bindings \\ []) do
      :code.priv_dir(:webpipe)
      |> Path.join(name)
      |> File.read!()
      |> EEx.eval_string(bindings)
    end

    def not_found(_method, path, req) do
      resp =
        :cowboy_req.reply(
          404,
          %{"content-type" => "text/html; charset=utf-8"},
          "<!doctype html> <h1>404</h1> Resource `#{ path }` not found!",
          req
        )

      {:ok, resp, []}
    end

    def session_handler("GET", id, req) do
      resp =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/html; charset=utf-8"},
          render_page("session.html", session_id: id),
          req
        )

      {:ok, resp, []}
    end

    def session_handler(_, id, req) do
      {:ok, req} = read_body_loop(id, req)

      resp =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/plain; charset=utf-8"},
          "OK",
          req
        )

      {:ok, resp, []}
    end

    def read_body_loop(id, req) do
      case :cowboy_req.read_body(req, %{period: 100}) do
        {:more, data, req} ->
          push_data(id, data)
          read_body_loop(id, req)

        {:ok, data, req} ->
          push_data(id, data)
          {:ok, req}
      end
    end

    defp push_data(_id, ""), do: :noop
    defp push_data(id, data) do
      :ets.lookup(:sessions, id) # => []
      |> Enum.each(fn {_id, listener} ->
        send(listener, {:data, data})
      end)
    end

    def session_eventsource_handler(id, req) do
      :ets.insert(:sessions, {id, self()})

      req = :cowboy_req.stream_reply(200, %{
        "content-type" => "text/event-stream",
      }, req)

      :erlang.send_after(10, self(), :tick)

      {:cowboy_loop, req, []}
    end

    def info(:tick, req, state) do
      # :erlang.send_after(1000, self(), :tick)

      emit_event("Pipe check", req)
      {:ok, req, state}
    end

    def info({:data, data}, req, state) do
      emit_event(data, req)
      {:ok, req, state}
    end

    def info(msg, req, state) do
      Logger.warn "UNKNOWN MSG #{inspect msg}"
      {:ok, req, state}
    end

    defp emit_event(data, req) do
      :cowboy_req.stream_events(%{
        id: id(),
        data: Jason.encode!(%{line: data}),
      }, :nofin, req)
    end

    # TODO: handle terminate

    def id, do: :erlang.unique_integer([:positive, :monotonic]) |> to_string

  end

  defmodule Router do
    def routes do
      :cowboy_router.compile([
        {:_,
         [
           {:_, HTTPHandler, []},
         ]}
      ])
    end
  end

  defmodule Server do
    def start do
      # {"foo" => [#<PID1>, #<PID2>], "bar"....}
      :ets.new(:sessions, [:named_table, :public, :bag])
      :cowboy.start_clear(:http, [port: 8080], %{env: %{dispatch: Router.routes()}})
    end

    def stop do
      :cowboy.stop_listener(:http)
    end
  end
end
