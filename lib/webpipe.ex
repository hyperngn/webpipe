defmodule Webpipe do
  defmodule IDGenerator do
    def generate() do
      Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    end
  end

  defmodule Templates do
    require EEx
    @templates :code.priv_dir(:webpipe) |> Path.join("templates/*.html.eex") |> Path.wildcard()

    for template <- @templates do
      fn_name = template |> Path.basename() |> String.to_atom()
      EEx.function_from_file(:def, fn_name, template, [:assigns])
    end
  end

  defmodule HTTPHandler do
    import Logger, only: [info: 1]

    alias Webpipe.{SessionStore, Templates}

    def init(req, _opts) do
      info([req.method, " ", req.path, " PID:", inspect(self())])

      case {req.method, req.path} do
        {"GET", "/"} ->
          index_page(req)

        {"GET", "/session-sse/" <> id} ->
          session_eventsource_handler(id, req)

        {method, "/session/" <> id} when method in ~w[GET PUT POST PATCH] ->
          session_handler(method, id, req)

        {"GET", "/static/" <> asset} ->
          static_handler(asset)

        {method, path} ->
          not_found(method, path, req)
      end
    end

    def static_handler(req) do
      resp =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/html; charset=utf-8"},
          "",
          req
        )

      {:ok, resp, []}
    end

    def index_page(req) do
      resp =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/html; charset=utf-8"},
          render_template(:"index.html.eex", %{
            session_url: "https://webpipe.hyperngn.com/session/#{IDGenerator.generate()}"
          }),
          req
        )

      {:ok, resp, []}
    end

    def render_template(name, assigns) when is_atom(name) do
      apply(Templates, name, [assigns])
    end

    def not_found(_method, path, req) do
      resp =
        :cowboy_req.reply(
          404,
          %{"content-type" => "text/html; charset=utf-8"},
          "<!doctype html> <h1>404</h1> Resource `#{path}` not found!",
          req
        )

      {:ok, resp, []}
    end

    def session_handler("GET", id, req) do
      resp =
        :cowboy_req.reply(
          200,
          %{"content-type" => "text/html; charset=utf-8"},
          render_template(:"session.html.eex", %{session_id: id}),
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
      # => []
      id
      |> SessionStore.get_listeners()
      |> Enum.each(fn listener ->
        send(listener, {:data, data})
      end)
    end

    def session_eventsource_handler(id, req) do
      SessionStore.register_listener(id)

      req =
        :cowboy_req.stream_reply(
          200,
          %{
            "content-type" => "text/event-stream"
          },
          req
        )

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
      Logger.warn("UNKNOWN MSG #{inspect(msg)}")
      {:ok, req, state}
    end

    defp emit_event(data, req) do
      :cowboy_req.stream_events(
        %{
          id: id(),
          data: Jason.encode!(%{line: data})
        },
        :nofin,
        req
      )
    end

    # TODO: handle terminate

    def id, do: :erlang.unique_integer([:positive, :monotonic]) |> to_string
  end

  defmodule Router do
    def routes do
      :cowboy_router.compile([
        {:_,
         [
           {:_, HTTPHandler, []}
         ]}
      ])
    end
  end

  defmodule Server do
    use GenServer
    require Logger

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    @impl GenServer
    def init(opts) do
      port = opts[:port] || 8080
      Logger.info("Starting HTTP Server at http://localhost:#{port}/")
      :cowboy.start_clear(:http, [port: port], %{env: %{dispatch: Router.routes()}})
      {:ok, :state}
    end

    @impl GenServer
    def terminate(_reason, _state) do
      :cowboy.stop_listener(:http)
    end
  end

  defmodule SessionStore do
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
end
