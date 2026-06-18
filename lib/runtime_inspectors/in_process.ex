defmodule Beamulator.RuntimeInspectors.InProcess do
  @behaviour Beamulator.RuntimeInspector
  alias Beamulator.Lab

  @impl true
  def stats(), do: Beamulator.DashboardStatsProvider.get_stats()

  @impl true
  def actors() do
    Lab.Actor.select_all()
    |> Enum.map(&actor_summary/1)
  end

  @impl true
  def actor(serial_id) when is_integer(serial_id) do
    case Lab.Actor.get_state(serial_id) do
      {:ok, state} -> {:ok, actor_detail(state)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def behaviors() do
    Lab.Actor.select_all()
    |> Enum.group_by(& &1.behavior)
    |> Enum.map(fn {behavior, defs} ->
      %{
        name: inspect(behavior),
        count: length(defs),
        actors: Enum.map(defs, & &1.name)
      }
    end)
  end

  @impl true
  def complaints() do
    if Process.whereis(Beamulator.Sinks.Memory) do
      Beamulator.Sinks.Memory.complaints()
      |> Enum.map(&complaint_summary/1)
    else
      []
    end
  end

  defp actor_summary(%ActorDefinition{} = def) do
    %{
      serial_id: def.serial_id,
      name: def.name,
      behavior: inspect(def.behavior),
      pid: inspect(def.pid)
    }
  end

  defp actor_detail(state) do
    %{
      serial_id: state.serial_id,
      name: state.name,
      behavior: inspect(state.behavior),
      pid: inspect(self()),
      tags: MapSet.to_list(state.tags),
      runtime_stats: state.runtime_stats,
      config: state.config,
      state: state.state
    }
  end

  defp complaint_summary(c) do
    %{
      actor_id: c.actor_id |> Tuple.to_list() |> Enum.map(&inspect/1),
      message: c.message,
      severity: c.severity,
      sim_time_ms: c.sim_time_ms,
      meta: c.meta
    }
  end
end
