defmodule Beamulator.RuntimeInspectorTest do
  use ExUnit.Case, async: false
  alias Beamulator.RuntimeInspector
  alias Beamulator.Sinks.Memory
  alias Beamulator.Clock
  alias Beamulator.Lab.Duration, as: D

  defmodule Probe do
    alias Beamulator.Actions
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Role

    @impl true
    def default_tags(), do: MapSet.new(["role:probe"])

    @impl true
    def default_state(), do: %{ticks: 0}

    @impl true
    def act(%{actor_state: state} = actor_data) do
      execute(actor_data, &Actions.send_collected_metrics/1, [[state.ticks]])
      {:ok, D.new(s: 10), %{actor_data | actor_state: %{state | ticks: state.ticks + 1}}}
    end
  end

  setup do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Beamulator.SupervisorActors) do
      if is_pid(pid), do: DynamicSupervisor.terminate_child(Beamulator.SupervisorActors, pid)
    end

    wait_until_registry_empty()

    Memory.reset()

    {:ok, pid} = Beamulator.SupervisorActors.create_actor("Probe 1", Probe, %{flag: true})
    GenServer.call(pid, :state, 5_000)

    state = GenServer.call(pid, :state)
    {:ok, pid: pid, serial_id: state.serial_id}
  end

  defp wait_until_registry_empty(deadline_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + deadline_ms

    wait = fn loop ->
      if Beamulator.Lab.Actor.select_all() == [] do
        :ok
      else
        if System.monotonic_time(:millisecond) > deadline do
          raise "actor registry did not clear within #{deadline_ms}ms"
        end

        Process.sleep(10)
        loop.(loop)
      end
    end

    wait.(wait)
  end

  test "stats/0 returns the expected shape" do
    s = RuntimeInspector.stats()
    assert is_map(s)
    assert Map.has_key?(s, :actions_total)
    assert Map.has_key?(s, :actions_successful)
    assert Map.has_key?(s, :actions_failed)
    assert s.actions_total >= 1
  end

  test "actors/0 returns one Probe summary", %{serial_id: serial_id} do
    actors = RuntimeInspector.actors()
    assert [%{name: "Probe 1", role: role_str, serial_id: ^serial_id}] = actors
    assert role_str =~ "Probe"
  end

  test "actor/1 returns full state including runtime_stats and config", %{serial_id: serial_id} do
    {:ok, detail} = RuntimeInspector.actor(serial_id)
    assert detail.name == "Probe 1"
    assert detail.config == %{flag: true}
    assert detail.state == %{ticks: 1}
    assert detail.runtime_stats.action_count == 1
    assert "role:probe" in detail.tags
  end

  test "roles/0 groups by module", %{} do
    [b] = RuntimeInspector.roles()
    assert b.name =~ "Probe"
    assert b.count == 1
    assert b.actors == ["Probe 1"]
  end

  test "complaints/0 returns []" do
    assert RuntimeInspector.complaints() == []
  end

  test "after Clock.advance + sync, actor/1 reflects new tick", %{pid: pid, serial_id: serial_id} do
    {:ok, before} = RuntimeInspector.actor(serial_id)
    assert :ok = Clock.advance(D.new(s: 10))
    GenServer.call(pid, :state, 5_000)
    {:ok, after_} = RuntimeInspector.actor(serial_id)

    assert after_.runtime_stats.action_count == before.runtime_stats.action_count + 1
    assert after_.state.ticks == before.state.ticks + 1
  end
end
