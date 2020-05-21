defmodule Webpipe do
  defmodule HTTPHandler do
    import Logger, only: [info: 1]

    def init(req, _opts) do
      info [req.method, " ", req.path]

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

    defp render_page(name, bindings \\ []) do
      index_html =
        :code.priv_dir(:webpipe)
        |> Path.join(name)
        |> File.read!()
        |> EEx.eval_string(bindings)

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

    def session_eventsource_handler(id, req) do
      req = :cowboy_req.stream_reply(200, %{
        "content-type" => "text/event-stream",
      }, req)

      :erlang.send_after(1000, self(), :tick)

      {:cowboy_loop, req, []}
    end

    def info(:tick, req, state) do
      :cowboy_req.stream_events(%{
        id: id(),
        data: "This is amazing"
      }, :nofin, req)

      :erlang.send_after(1000, self(), :tick)

      {:ok, req, state}
    end

    def id, do: :erlang.unique_integer([:positive, :monotonic]) |> to_string

    def session_handler(_, id, req) do
       #info("#init req: #{inspect(req)} opts: #{inspect(opts)}")
       #{:ok, req} = read_body(req)

       #resp =
       #:cowboy_req.reply(200, %{"content-type" => "text/plain; charset=utf-8"}, "Hello!", req)

       #info "resp: #{ inspect(resp) }"

       #{:ok, resp, opts}
    end


    def read_body(req) do
      IO.puts(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")

      case :cowboy_req.read_body(req, %{period: 100}) do
        {:more, data, req} ->
          IO.inspect(data, label: ">>")
          read_body(req)

        {:ok, data, req} ->
          IO.inspect(data, label: ">>")
          IO.puts(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
          {:ok, req}
      end
    end
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
      :cowboy.start_clear(:http, [port: 8080], %{env: %{dispatch: Router.routes()}})
    end

    def stop do
      :cowboy.stop_listener(:http)
    end
  end
end
