defmodule Beamulator.Behaviors.Fooizer do
  alias Beamulator.Tools.Signal.PatchPresets
  alias Beamulator.Tools.Signal.Patch
  alias Beamulator.Clock
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Tools.Signal
  alias Beamulator.Tools.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @decision_wait_ms D.new(m: 10)

  @impl true
  def default_state() do
    %{
      metric: 100,
      patch: PatchPresets.slope(5),
    }
  end

  @impl true
  def act(_tick, %{actor_state: state} = actor_data) do
    simulation_now = Clock.get_simulation_now()

    if :rand.uniform() < 0.2 do
      Patch.start(state.patch, simulation_now, D.new(m: 60))
    end

    state = %{state | metric: Signal.patch!(state.metric, state.patch)}

    updated =
      Signal.normal(state.metric, 0, 0.1)
      # |> Signal.square(state.metric, simulation_now, 3, D.new(s: 20))
      # |> Signal.sine(simulation_now, 2, D.new(h: 12), 0)

    Logger.info("Value at #{DateTime.from_unix!(simulation_now, :millisecond)}: #{updated}")

    actor_data = %{actor_data | actor_state: state}

    execute(actor_data, &Actions.do_foo/1, updated)
    wait(actor_data)
  end

  defp wait(actor_data) do
    to_wait = @decision_wait_ms

    {:ok, to_wait, actor_data}
  end
end
