defmodule Beamulacrum.Application do
  use Application

  def start(_type, _args) do
    IO.puts("Starting Beamulacrum...")

    # Beamulacrum.ModuleLoader.load_user_modules(@user_module_path)

    children = [
      {Registry, keys: :unique, name: Beamulacrum.ActorRegistry},
      {Beamulacrum.Ticker, []},
      {Beamulacrum.ActorSupervisor, []}
    ]

    IO.puts("Starting the simulation tree")
    opts = [strategy: :one_for_one, name: :main_supervisor]
    {:ok, spid} = Supervisor.start_link(children, opts)

    Beamulacrum.ActorSupervisor.start_actor("wanderer_1", Beamulacrum.Behaviors.Wanderer)

    IO.puts("Application started successfully")

    {:ok, spid}
  end
end
