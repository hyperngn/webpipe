defmodule Webpipe do
  defmodule HTTPHandler do
    import Logger, only: [info: 1]

    def init(req, opts) do
      info("#init req: #{inspect(req)} opts: #{inspect(opts)}")

      resp =
        :cowboy_req.reply(200, %{"content-type" => "text/plain; charset=utf-8"}, "Hello!", req)

      {:ok, resp, opts}
    end

    def handle(request, state) do
      info(inspect({request, state}))

      {:ok, response} =
        :cowboy_req.reply(
          200,
          [],
          "Hello, World!",
          request
        )

      info(inspect(response))
      {:ok, response, state}
    end
  end

  defmodule Router do
    def routes do
      :cowboy_router.compile([
        {:_,
         [
           {"/", HTTPHandler, []}
         ]}
      ])
    end
  end

  defmodule Server do
    def start_server do
      :cowboy.start_clear(:http, [port: 8080], env: %{dispatch: Router.routes()})
    end
  end
end
