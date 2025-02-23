defmodule Beamulacrum.SupervisorRoot do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Beamulacrum.Behavior.Registry, []},
      {Registry, keys: :duplicate, name: Beamulacrum.ActorRegistry},
      {Beamulacrum.SupervisorActors, []},
      {Beamulacrum.Clock, []},
      # {Beamulacrum.Worker, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
