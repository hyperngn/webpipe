defmodule Webpipe.Router do
  def routes do
    :cowboy_router.compile([
      {:_,
       [
         {:_, HTTPHandler, []}
       ]}
    ])
  end
end
