defmodule Beamulator.Roles.Sensor do
  @moduledoc """
  Single sensor. Emits a signal per tick.

  Failure-scenario flag: `stuck?` — set at boot for a small fraction of the
  population. Stuck sensors emit a constant value, which the collector
  detects via a variance check and surfaces as a complaint.
  """

  alias Beamulator.Lab
  alias Beamulator.Lab.Signal.PatchPresets
  alias Beamulator.Lab.Signal.Patch
  alias Beamulator.Lab.Signal
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Role
  require Logger

  expose_actions []

  @tick D.new(s: 60)
  @stuck_probability 0.08

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state() do
    metric_type = Enum.random(["temperature", "humidity", "pressure"])
    base = base_for(metric_type)

    %{
      collector_serial_id: nil,
      metric_type: metric_type,
      metric_current: base,
      metric_base: base,
      stuck?: :rand.uniform() < @stuck_probability,
      patch: PatchPresets.peak(5)
    }
  end

  @impl true
  def act(%{simulation_data: simulation, actor_state: state} = actor_data) do
    simulation_now = simulation.now_ms

    new_value =
      if state.stuck? do
        state.metric_base
      else
        Signal.normal(state.metric_base, 0, base_noise(state.metric_base))
        |> Signal.patch!(state.patch)
      end

    if not state.stuck? and :rand.uniform() < 0.03 do
      Patch.start(state.patch, simulation_now, D.new(m: 60))
    end

    state = %{state | metric_current: new_value}
    state = ensure_collector_assigned(state)

    {:ok, @tick, %{actor_data | actor_state: state}}
  end

  defp ensure_collector_assigned(%{collector_serial_id: nil} = state) do
    case Lab.Actor.select_by_role(Beamulator.Roles.Collector) do
      [] ->
        state

      collectors ->
        %{serial_id: cid} = Enum.random(collectors)
        Lab.Actor.set_tags(self(), ["owner:collector:#{cid}"])
        %{state | collector_serial_id: cid}
    end
  end

  defp ensure_collector_assigned(state), do: state

  defp base_for("temperature"), do: 20.0 + :rand.uniform() * 5.0
  defp base_for("humidity"), do: 45.0 + :rand.uniform() * 10.0
  defp base_for("pressure"), do: 1010.0 + :rand.uniform() * 8.0

  defp base_noise(b) when b > 100, do: 1.0
  defp base_noise(_), do: 0.2
end
