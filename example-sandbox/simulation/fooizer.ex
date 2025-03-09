defmodule Beamulator.Behaviors.Fooizer do
  alias Beamulator.Tools
  alias Beamulator.Tools.Signal.PatchPresets
  alias Beamulator.Tools.Signal.Patch
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Tools.Signal
  alias Beamulator.Utils.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @decision_wait_ms D.new(m: 10)

  @impl true
  def default_state() do
    %{
      collector_serial_id: nil,
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

    # |> Signal.square(state.metric, simulation_now, 3, D.new(s: 20))
    # |> Signal.sine(simulation_now, 2, D.new(h: 12), 0)

    if :rand.uniform() < 0.03 do
      Patch.start(state.patch, simulation_now, D.new(m: 60))
    end

    state = %{state | metric_current: new_metric_value}
    actor_data = %{actor_data | actor_state: state}

    execute(actor_data, &Actions.do_foo/1, new_metric_value)

    state =
      with nil <- state.collector_serial_id,
           %{serial_id: collector_serial_id} <-
             Tools.Actor.select_by_behavior(Beamulator.Behaviors.Collector)
             |> Enum.random() do
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
