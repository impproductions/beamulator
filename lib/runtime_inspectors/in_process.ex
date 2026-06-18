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
  def roles() do
    Lab.Actor.select_all()
    |> Enum.group_by(& &1.role)
    |> Enum.map(fn {role, defs} ->
      %{
        name: inspect(role),
        count: length(defs),
        actors: Enum.map(defs, & &1.name)
      }
    end)
  end

  @impl true
  def actions_for(role) when is_binary(role) do
    case safe_string_to_module(role) do
      {:ok, mod} -> actions_for(mod)
      :error -> []
    end
  end

  def actions_for(role) when is_atom(role) do
    if Code.ensure_loaded?(role) and function_exported?(role, :actions, 0) do
      role.actions()
      |> Enum.map(fn %{name: name, default_args: default_args} ->
        %{name: name, default_args: default_args}
      end)
    else
      []
    end
  end

  defp safe_string_to_module(name) do
    candidate = if String.starts_with?(name, "Elixir."), do: name, else: "Elixir." <> name
    {:ok, String.to_existing_atom(candidate)}
  rescue
    ArgumentError -> :error
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
      role: inspect(def.role),
      pid: inspect(def.pid)
    }
  end

  defp actor_detail(state) do
    %{
      serial_id: state.serial_id,
      name: state.name,
      role: inspect(state.role),
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
