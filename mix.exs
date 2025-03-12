defmodule Beamulator.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamulator,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Include priv folder (and other files you need) in the release package
      files: ~w(lib priv mix.exs README.md),
      releases: [
        beamulator: [
          version: "0.1.0",
          vm_args: "rel/vm.args",
          # Custom release step to copy priv into the release
          steps: [:assemble, &copy_priv/1]
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
  defp simulation_path(), do: "example-sensors-no-backend/simulation"

  defp deps do
    [
      {:faker, "~> 0.18"},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.2"},
      {:logger_file_backend, "~> 0.0.12"},
      {:plug_cowboy, "~> 2.0"},
      {:uuid, "~> 1.1"}
    ]
  end

  # Custom release step that copies the priv folder into the release directory.
  defp copy_priv(release) do
    source = "priv"
    dest = Path.join(release.path, "priv")
    case File.cp_r(source, dest) do
      {:ok, _} ->
        Mix.shell().info("Successfully copied priv folder to release.")
      {:error, reason, _} ->
        Mix.shell().error("Failed to copy priv folder: #{inspect(reason)}")
    end
    release
  end
end
