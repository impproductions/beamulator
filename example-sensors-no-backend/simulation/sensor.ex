defmodule Beamulator.Behaviors.Sensor do
  alias Beamulator.Lab
  alias Beamulator.Lab.Signal.PatchPresets
  alias Beamulator.Lab.Signal.Patch
  alias Beamulator
  alias Beamulator.Lab.Signal
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @decision_wait_ms D.new(m: 5)

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state() do
    %{
      collector_serial_id: nil,
      metric_type: Enum.random(["temperature", "humidity", "pressure"]),
      metric_current: 0,
      metric_base: 5,
      patch: PatchPresets.peak(5)
    }
  end

  @impl true
  def act(%{simulation_data: simulation, actor_state: state} = actor_data) do
    simulation_now = simulation.now_ms

    new_metric_value =
      Signal.normal(state.metric_base, 0, 0.1)
      |> Signal.patch!(state.patch)

    if :rand.uniform() < 0.03 do
      Patch.start(state.patch, simulation_now, D.new(m: 60))
    end

    state = %{state | metric_current: new_metric_value}
    actor_data = %{actor_data | actor_state: state}

    state =
      with nil <- state.collector_serial_id,
           collectors when collectors != [] <-
             Lab.Actor.select_by_behavior(Beamulator.Behaviors.Collector),
           %{serial_id: collector_serial_id} <-
             collectors |> Enum.random() do
        Lab.Actor.set_tags(self(), ["owner:collector:#{collector_serial_id}"])
        %{state | collector_serial_id: collector_serial_id}
      else
        _ -> state
      end

    actor_data = %{actor_data | actor_state: state}
    wait(actor_data)
  end

  defp wait(actor_data) do
    to_wait = @decision_wait_ms

    {:ok, to_wait, actor_data}
  end
end
