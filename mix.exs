defmodule Beamulacrum.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamulacrum,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:logger_file_backend, "~> 0.0.12"},
        {:timex, "~> 3.7"},
        {:uuid, "~> 1.1"}
      ],
      elixirc_paths: elixirc_paths()
    ]
  end

  def application do
    [
      # Start Beamulacrum on launch
      mod: {Beamulacrum.Application, []},
      extra_applications: [:logger]
    ]
  end

  def escript do
    [main_module: Beamulacrum]
  end

  defp elixirc_paths(), do: ["lib", "simulacrum"]
end
