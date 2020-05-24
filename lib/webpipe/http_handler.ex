defmodule Webpipe.HTTPHandler do
  import Logger, only: [info: 1]

  alias Webpipe.{SessionStore, Templates, Assets, IDGenerator}

  def init(req, _opts) do
    info([req.method, " ", req.path, " PID:", inspect(self())])

    case {req.method, req.path} do
      {"GET", "/"} ->
        index_page(req)

      {"GET", "/favicon.ico"} ->
        static_handler("favicon.svg", req)

      {"GET", "/session-sse/" <> id} ->
        session_eventsource_handler(id, req)

      {method, "/session/" <> id} when method in ~w[GET PUT POST PATCH] ->
        session_handler(method, id, req)

      {"GET", "/static/" <> asset_path} ->
        static_handler(asset_path, req)

      {method, path} ->
        not_found(method, path, req)
    end
  end

  def static_handler(asset_path, req) do
    {mime_type, asset_contents} = Assets.for_path(asset_path)

    render_response(asset_contents, req, mime_type, %{
      "cache-control" => "public, max-age=86400"
    })
  end

  defp render_response(
         resp_body,
         req,
         content_type \\ "text/html; charset=utf-8",
         http_headers \\ %{}
       ) do
    resp =
      :cowboy_req.reply(
        200,
        Map.merge(
          %{
            "content-type" => content_type,
            "strict-transport-security" => "max-age=63072000"
          },
          http_headers
        ),
        resp_body,
        req
      )

    {:ok, resp, []}
  end

  defp index_page(req) do
    :"index.html.eex"
    |> render_template(%{
      session_url: "https://webpipe.hyperngn.com/session/#{IDGenerator.generate()}"
    })
    |> render_response(req)
  end

  defp not_found(_method, path, req) do
    render_response("<!doctype html> <h1>404</h1> Resource `#{path}`.", req)
  end

  def session_handler("GET", id, req) do
    :"session.html.eex"
    |> render_template(%{
      session_id: id
    })
    |> render_response(req)
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

  defp render_template(name, assigns) when is_atom(name) do
    apply(Templates, name, [assigns])
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

    :erlang.send_after(10, self(), :pipe_check)
    send(self(), :heartbeat)

    {:cowboy_loop, req, []}
  end

  def info(:pipe_check, req, state) do
    emit_event("Pipe check", req)
    {:ok, req, state}
  end

  # 1 second
  @heartbeat_interval 1000
  def info(:heartbeat, req, state) do
    emit_event("", req)
    :erlang.send_after(@heartbeat_interval, self(), :heartbeat)
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
        data: Jason.encode!(%{line: data})
      },
      :nofin,
      req
    )
  end

  # TODO: handle terminate
end
