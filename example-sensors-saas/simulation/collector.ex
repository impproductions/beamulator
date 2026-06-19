defmodule Beamulator.Roles.Collector do
  @moduledoc """
  Collects readings from its assigned sensors and POSTs them to the SaaS
  backend.

  Failure-scenario flags (set at boot):
    * `flaky?`     — occasionally drops a required field, triggering 400s.
    * Stuck sensors are detected here via a variance window: a collector
      maintains the last N readings per sensor and complains when variance
      is zero.

  Complaints fired by this role:
    * `ingest_rejected`   — backend returned 400 (bad payload)
    * `backend_outage`    — backend returned 503 (chaos / dead)
    * `transport_failure` — connection refused / timeout
    * `stuck_sensor`      — a sensor's reading window has zero variance
  """

  alias Beamulator.Lab
  alias Beamulator.Actions
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Role
  import Beamulator.Role.ComplaintBuilder
  require Logger

  expose_actions [
    {:send_collected_metrics,
     default_args: [
       %{
         collector_id: "ManualTrigger",
         readings: [
           %{sensor_id: 999, metric: "manual_probe", value: 42.0, ts_ms: 1750291200000}
         ]
       }
     ]}
  ]

  @tick D.new(s: 30)
  @flaky_collector_probability 0.10
  @variance_window 6

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state() do
    %{
      flaky?: :rand.uniform() < @flaky_collector_probability,
      windows: %{}
    }
  end

  @impl true
  def act(
        %{
          simulation_data: simulation,
          actor_state: state,
          actor_serial_id: serial_id,
          actor_name: name
        } = actor_data
      ) do
    readings = gather_readings(serial_id, simulation.now_ms)

    new_windows = update_windows(state.windows, readings)
    stuck_sensors = find_stuck(new_windows)
    state = %{state | windows: new_windows}
    actor_data = %{actor_data | actor_state: state}

    actor_data =
      if readings != [] do
        payload = build_payload(name, readings, state.flaky?)

        execute(
          actor_data,
          &Actions.send_collected_metrics/1,
          payload,
          complaints_for(stuck_sensors)
        )

        actor_data
      else
        actor_data
      end

    {:ok, @tick, actor_data}
  end

  defp gather_readings(serial_id, sim_now_ms) do
    Lab.Actor.select_by_role(Beamulator.Roles.Sensor)
    |> Lab.Actor.filter_by_tag("owner:collector:#{serial_id}")
    |> Enum.map(fn %{pid: pid, serial_id: sid} ->
      %{state: %{metric_type: mt, metric_current: mc}} = Lab.Actor.get_state!(pid)
      %{sensor_id: sid, metric: mt, value: mc, ts_ms: sim_now_ms}
    end)
  end

  defp build_payload(name, readings, flaky?) do
    readings =
      if flaky? and :rand.uniform() < 0.30 do
        corrupt_one(readings)
      else
        readings
      end

    %{collector_id: name, readings: readings}
  end

  defp corrupt_one([]), do: []

  defp corrupt_one(readings) do
    idx = :rand.uniform(length(readings)) - 1

    List.update_at(readings, idx, fn r ->
      Map.delete(r, :metric)
    end)
  end

  defp update_windows(windows, readings) do
    Enum.reduce(readings, windows, fn %{sensor_id: sid, value: v}, acc ->
      w = Map.get(acc, sid, [])
      w = [v | w] |> Enum.take(@variance_window)
      Map.put(acc, sid, w)
    end)
  end

  defp find_stuck(windows) do
    for {sid, w} <- windows, length(w) >= @variance_window, zero_variance?(w), do: sid
  end

  defp zero_variance?([]), do: false
  defp zero_variance?([h | t]), do: Enum.all?(t, fn x -> x == h end)

  defp complaints_for(stuck_sensors) do
    [
      build_complaint(
        fn {status, result} ->
          status == :error and is_binary(result) and String.starts_with?(result, "rejected")
        end,
        "Backend rejected ingest payload",
        :urgent
      ),
      build_complaint(
        fn {status, result} ->
          status == :error and is_binary(result) and String.contains?(result, "503")
        end,
        "Backend unavailable 503",
        :urgent
      ),
      build_complaint(
        fn {status, result} ->
          status == :error and is_binary(result) and String.contains?(result, "transport")
        end,
        "Transport failure reaching backend",
        :urgent
      ),
      build_complaint(
        fn {_status, _result} -> stuck_sensors != [] end,
        "Stuck sensor(s) detected: #{inspect(stuck_sensors)}",
        :annoying
      )
    ]
  end
end
