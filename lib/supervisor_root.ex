defmodule Beamulator.SupervisorRoot do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Beamulator.Behavior.Registry, []},
      {Registry, keys: :duplicate, name: Beamulator.ActorRegistry},
      {Beamulator.SupervisorActors, []},
      {Beamulator.Clock, []},
      # {Beamulator.Worker, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
