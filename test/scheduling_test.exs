defmodule Beamulator.SchedulingTest do
  use ExUnit.Case, async: false
  alias Beamulator.Clock

  test "advance/1 delivers matured ticks to the registered pid in due-order" do
    now = Clock.get_simulation_now()

    assert :ok = Clock.schedule_at(self(), :tick_a, now + 1_000)
    assert :ok = Clock.schedule_at(self(), :tick_b, now + 5_000)

    assert :ok = Clock.advance(2_000)
    assert_received :tick_a
    refute_received :tick_b

    assert :ok = Clock.advance(3_000)
    assert_received :tick_b
  end

  test "set_now/1 also dispatches matured ticks" do
    now = Clock.get_simulation_now()
    assert :ok = Clock.schedule_at(self(), :jumped, now + 10_000)

    assert :ok = Clock.set_now(now + 10_000)
    assert_received :jumped
  end

  test "schedule_at/3 returns {:error, :auto_mode} against an :auto Clock" do
    name = :"#{__MODULE__}.AutoClock"
    {:ok, _pid} = Clock.start_link(name: name, mode: :auto, start_time: DateTime.utc_now())

    assert {:error, :auto_mode} = Clock.schedule_at(name, self(), :nope, 0)
  end
end
