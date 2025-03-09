defmodule Beamulator.Behaviors.Collector do
  alias Beamulator.Tools
  alias Beamulator.Tools.Signal.PatchPresets
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Tools.Duration, as: D
  use Beamulator.Behavior
  require Logger

  @decision_wait_ms D.new(m: 30)

  @impl true
  def default_state() do
    %{
      metric: 5,
      patch: PatchPresets.peak(5)
    }
  end

  @impl true
  def act(
        %{simulation_data: _simulation, actor_state: _state, actor_serial_id: serial_id} =
          actor_data
      ) do
    Logger.info("Collector is collecting data")

    fooizers =
      Tools.Actors.select_by_behavior(Beamulator.Behaviors.Fooizer)
      |> Enum.map(fn {pid, _} ->
        Tools.Actors.get_state(pid)
      end)
      |> Enum.filter(fn data -> data.state.collector_serial_id == serial_id end)
      |> Enum.map(fn data -> "#{data.name}: #{data.state.metric_current}" end)
      |> Enum.join("|")

    if fooizers != [] do
      execute(actor_data, &Actions.do_bar/1, [fooizers])
    end

    wait(actor_data)
  end

  defp wait(actor_data) do
    to_wait = @decision_wait_ms

    {:ok, to_wait, actor_data}
  end
end
