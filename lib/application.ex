defmodule Beamulacrum.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting Beamulacrum...")


    Logger.add_backend({LoggerFileBackend, :file_logger})
    Logger.configure(level: :info, backends: [:console, :file_logger])

    simulatiom_config = Application.fetch_env!(:beamulacrum, :simulation)
    random_seed = simulatiom_config[:random_seed]

    IO.puts("Random seed: #{random_seed}")
    :rand.seed(:exsss, random_seed)

    children = [
      {Registry, keys: :unique, name: Beamulacrum.ActorRegistry},
      {Beamulacrum.Ticker, []},
      {Beamulacrum.ActorSupervisor, []}
    ]

    IO.puts("Starting the simulation tree")
    opts = [strategy: :one_for_one, name: :main_supervisor]
    {:ok, spid} = Supervisor.start_link(children, opts)

    actors_config = Application.fetch_env!(:beamulacrum, :actors)

    IO.inspect(actors_config, label: "actors_config")

    actors_config
    |> Enum.each(fn conf ->
      %{name: name, behavior: behavior, config: config, amt: amt} = conf

      for _ <- 1..amt,
          do:
            Beamulacrum.ActorSupervisor.start_actor(
              name <> " " <> to_string(:erlang.unique_integer([:monotonic, :positive])),
              behavior,
              config
            )
    end)

    IO.puts("Application started successfully")

    {:ok, spid}
  end
end
