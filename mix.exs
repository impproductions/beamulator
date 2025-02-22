defmodule Beamulacrum.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamulacrum,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:faker, "~> 0.18"},
        {:httpoison, "~> 2.2"},
        {:jason, "~> 1.2"},
        {:logger_file_backend, "~> 0.0.12"},
        {:timex, "~> 3.7"},
        {:uuid, "~> 1.1"}
      ],
      releases: [
        beamulacrum: [
          version: "0.1.0",
          vm_args: "rel/vm.args"
        ]
      ],
      elixirc_paths: elixirc_paths()
    ]
  end

  def application do
    [
      mod: {Beamulacrum.Application, []},
      extra_applications: [:logger]
    ]
  end

  def escript do
    [main_module: Beamulacrum]
  end

  defp elixirc_paths(), do: ["lib", "simulacrum"]
end
