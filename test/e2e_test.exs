defmodule Beamulator.E2ETest do
  use ExUnit.Case, async: false
  alias Beamulator.Clock
  alias Beamulator.Sinks.Memory
  alias Beamulator.Lab.Duration, as: D

  defmodule TickEmitter do
    alias Beamulator.Actions
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Role

    @impl true
    def default_tags(), do: MapSet.new(["role:tick_emitter"])

    @impl true
    def default_state(), do: %{ticks: 0}

    @impl true
    def act(%{actor_state: state} = actor_data) do
      execute(actor_data, &Actions.send_collected_metrics/1, [[state.ticks]])
      new_state = %{state | ticks: state.ticks + 1}
      {:ok, D.new(s: 10), %{actor_data | actor_state: new_state}}
    end
  end

  test "Clock.advance fires registered actor ticks; role.act → MemorySink end-to-end" do
    # Clean slate: terminate any previously-spawned actors so they don't interfere.
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Beamulator.SupervisorActors) do
      if is_pid(pid), do: DynamicSupervisor.terminate_child(Beamulator.SupervisorActors, pid)
    end

    Memory.reset()

    {:ok, pid} =
      Beamulator.SupervisorActors.create_actor("TickEmitter 1", TickEmitter, %{})

    # Sync: wait for boot-time :start → :act → Clock.schedule_at.
    GenServer.call(pid, :state, 5_000)

    boot_events = Memory.events()
    assert length(boot_events) == 1
    assert hd(boot_events).actor_id == {TickEmitter, "TickEmitter 1"}
    assert hd(boot_events).success == true

    # Clock.advance fires only ticks due at the moment of call — re-registrations
    # during processing fire on the next advance. Step 10s at a time × 3 to get
    # 3 more ticks (at +10s, +20s, +30s).
    for _ <- 1..3 do
      assert :ok = Clock.advance(D.new(s: 10))
      GenServer.call(pid, :state, 5_000)
    end

    events = Memory.events()
    assert length(events) == 4

    Enum.each(events, fn e ->
      assert e.actor_id == {TickEmitter, "TickEmitter 1"}
      assert e.success == true
    end)

    sim_times = Enum.map(events, & &1.sim_time_ms)
    assert sim_times == Enum.sort(sim_times)

    assert Memory.complaints() == []
  end
end
