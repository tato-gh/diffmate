defmodule Diffmate.MixProject do
  use Mix.Project

  def project do
    [
      app: :diffmate,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.0"},
      {:yaml_elixir, "~> 2.9"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      build: ["escript.build"]
    ]
  end

  defp escript do
    [
      main_module: Diffmate.CLI,
      name: "diffmate",
      path: "bin/diffmate.escript"
    ]
  end
end
