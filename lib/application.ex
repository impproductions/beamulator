defmodule Beamulacrum.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting Beamulacrum...")

    Logger.add_backend({LoggerFileBackend, :file_logger})
    Logger.configure(level: :info, backends: [:console, :file_logger])

    random_seed = Beamulacrum.Tools.random_seed()

    IO.puts("Random seed: #{random_seed}")
    :rand.seed(:exsss, random_seed)

    children = [
      {Registry, keys: :unique, name: Beamulacrum.ActorRegistry},
      {Beamulacrum.Ticker, []},
      {Beamulacrum.ActorSupervisor, []}
    ]

    IO.puts("Starting the simulation tree")
    opts = [strategy: :one_for_one, name: :main_supervisor]
    {:ok, supervisor_pid} = Supervisor.start_link(children, opts)

    actors_config = Application.fetch_env!(:beamulacrum, :actors)

    IO.inspect(actors_config, label: "actors_config")

    actors_to_create =
      actors_config
      |> Enum.map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
        for _ <- 1..amt,
            do: %{
              name: name <> " " <> to_string(Beamulacrum.Tools.increasing_int()),
              behavior: behavior,
              config: config
            }
      end)
      |> List.flatten()

    _pids = Beamulacrum.Connectors.Internal.create_actors(actors_to_create)

    IO.puts("Application started successfully!")

    {:ok, supervisor_pid}
  end
end
