defmodule Beamulator.SinksTest do
  use ExUnit.Case, async: false
  alias Beamulator.Sinks
  alias Beamulator.Sinks.{Event, Complaint, Memory}

  setup do
    Memory.reset()
    :ok
  end

  test "fan_out_event/1 delivers to MemorySink" do
    event = %Event{
      actor_id: {SomeMod, "alice"},
      action: fn -> :ok end,
      args: [1, 2],
      result: {:ok, %{}},
      success: true,
      sim_time_ms: 0
    }

    assert :ok = Sinks.fan_out_event(event)
    assert [^event] = Memory.events()
  end

  test "fan_out_complaint/1 delivers to MemorySink" do
    complaint = %Complaint{
      actor_id: {SomeMod, "bob"},
      message: "violation",
      severity: :urgent,
      action: fn -> :ok end,
      args: nil,
      meta: %{trigger: "x", status: :ok, result: %{}},
      sim_time_ms: 0
    }

    assert :ok = Sinks.fan_out_complaint(complaint)
    assert [^complaint] = Memory.complaints()
  end

  test "ActionExecutor.exec/3 emits via the sink list — Memory sees it AND DashboardStats counters move" do
    before_stats = Beamulator.DashboardStatsProvider.get_stats()

    Beamulator.ActionExecutor.exec(
      {SomeMod, "carol"},
      fn -> {:ok, %{}} end,
      nil
    )

    after_stats = Beamulator.DashboardStatsProvider.get_stats()

    assert [%Event{actor_id: {SomeMod, "carol"}, success: true}] = Memory.events()
    assert after_stats.actions_successful == before_stats.actions_successful + 1
  end
end
