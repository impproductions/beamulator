defmodule Beamulator.SupervisorActors do
  use DynamicSupervisor
  require Logger

  def start_link(_) do
    Logger.info("Actor Supervisor started")
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Process.send_after(Beamulator.ActorInizializer, :create_actors, 10)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def create_actor(name, behavior_module, config) do
    Logger.debug("create actor: #{name}")
    spec = {Beamulator.Actor, {name, behavior_module, config}}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        Logger.debug("Child (actor #{name}) created successfully")
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Failed to create child (actor #{name}): #{inspect(reason)}")
        {:error, reason}
    end
  end
end
