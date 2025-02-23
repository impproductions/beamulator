defmodule Beamulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamulator,
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
        beamulator: [
          version: "0.1.0",
          vm_args: "rel/vm.args"
        ]
      ],
      elixirc_paths: elixirc_paths()
    ]
  end

  def application do
    [
      mod: {Beamulator.Application, []},
      extra_applications: [:logger]
    ]
  end

  def escript do
    [main_module: Beamulator]
  end

  defp elixirc_paths(), do: ["lib", simulation_path()]

  defp simulation_path(), do: "example-todo/simulation"
end
