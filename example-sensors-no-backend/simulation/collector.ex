defmodule Beamulator.Roles.Collector do
  alias Beamulator.Lab
  alias Beamulator.Actions
  alias Beamulator
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Role
  require Logger

  expose_actions [
    {:send_collected_metrics, default_args: [[[1, "temperature", 21.5]]]}
  ]

  @decision_wait_ms D.new(m: 30)

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state() do
    %{
      sensors: []
    }
  end

  @impl true
  def act(
        %{simulation_data: _simulation, actor_state: state, actor_serial_id: serial_id} =
          actor_data
      ) do
    Logger.info("Collector #{serial_id} is collecting data")

    fooizers =
      Lab.Actor.select_by_role(Beamulator.Roles.Sensor)
      |> Lab.Actor.filter_by_tag("owner:collector:#{serial_id}")
      |> Enum.map(fn %{pid: pid, serial_id: serial_id} ->
        %{state: %{metric_type: mt, metric_current: mc}} = Lab.Actor.get_state!(pid)
        [serial_id, mt, mc]
      end)

    if fooizers != [] do
      execute(actor_data, &Actions.send_collected_metrics/1, [fooizers])
    end

    actor_data = %{actor_data | actor_state: %{state | sensors: fooizers}}

    wait(actor_data)
  end

  defp wait(actor_data) do
    to_wait = div(@decision_wait_ms, 2) + :rand.uniform(@decision_wait_ms)

    {:ok, to_wait, actor_data}
  end
end
