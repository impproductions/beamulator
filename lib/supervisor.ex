defmodule Beamulacrum.ActorSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    IO.puts("Starting Actor Supervisor...")
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_actor(name, behavior_module) do
    spec = {Beamulacrum.Actor, {name, behavior_module}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
