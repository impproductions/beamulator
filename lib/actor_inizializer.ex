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

  def start_creation() do
    GenServer.call(__MODULE__, :create_actors, :infinity)
  end

  def handle_call(:create_actors, _from, state) do
    Logger.info("Creating actors...")
    create_actors()
    Logger.info("Actors created.")
    {:reply, :ok, state}
  end

  defp create_actors do
    actors_config = Application.fetch_env!(:beamulator, :actors)

    actors_config
    |> Enum.flat_map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
      for _ <- 1..amt do
        %{
          name: "#{name} #{Beamulator.Utils.increasing_int()}",
          behavior: behavior,
          config: config
        }
      end
    end)
    |> Enum.each(fn %{name: name, behavior: behavior, config: config} ->
      Beamulator.SupervisorActors.create_actor(name, behavior, config)
      maybe_sleep_between_spawns()
    end)

    Logger.info("Actors initialized successfully.")
  end

  defp maybe_sleep_between_spawns() do
    if deterministic_boot?() do
      :ok
    else
      Process.sleep(:rand.uniform(100) + 50)
    end
  end

  defp deterministic_boot?() do
    Application.fetch_env!(:beamulator, :simulation)[:deterministic_boot] == true
  end
end
