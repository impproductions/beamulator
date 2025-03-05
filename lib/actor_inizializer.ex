defmodule Beamulator.ActorInizializer do
  use GenServer
  require Logger

  def start_link(_) do
    Logger.info("Actor Inizializer started")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, []}
  end

  def handle_info(:create_actors, state) do
    Logger.info("Creating actors (staggered)...")
    create_actors()
    Logger.info("Actors created.")
    {:noreply, state}
  end

  defp create_actors do
    actors_config = Application.fetch_env!(:beamulator, :actors)

    actors_config
    |> Enum.flat_map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
      for _ <- 1..amt do
        %{
          name: "#{name} #{Beamulator.Tools.increasing_int()}",
          behavior: behavior,
          config: config
        }
      end
    end)
    |> Enum.each(fn %{name: name, behavior: behavior, config: config} ->
      Beamulator.SupervisorActors.create_actor(name, behavior, config)
      Process.sleep(:rand.uniform(100) + 50)
    end)

    Logger.info("Actors initialized successfully.")
  end

end
