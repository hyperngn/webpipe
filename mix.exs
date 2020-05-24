defmodule Webpipe.MixProject do
  use Mix.Project

  def project do
    [
      app: :webpipe,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Webpipe.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      cowboy: "~> 2.7.0",
      jason: "~> 1.2.0",
      mime: "~> 1.3.0"
    ]
  end
end
