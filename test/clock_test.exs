defmodule Beamulator.ClockTest do
  use ExUnit.Case, async: false
  alias Beamulator.Clock

  test "test suite Clock is in :manual mode" do
    assert Clock.mode() == :manual
  end

  test "advance/1 moves simulation time forward by the requested ms" do
    before_now = Clock.get_simulation_now()
    before_duration = Clock.get_simulation_duration_ms()

    assert :ok = Clock.advance(1_000)

    assert Clock.get_simulation_now() == before_now + 1_000
    assert Clock.get_simulation_duration_ms() == before_duration + 1_000
  end

  test "set_now/1 jumps to the requested absolute unix ms" do
    target = Clock.get_simulation_now() + 60_000
    assert :ok = Clock.set_now(target)
    assert Clock.get_simulation_now() == target
  end

  test "advance/1 and set_now/1 return {:error, :auto_mode} against an :auto Clock" do
    name = :"#{__MODULE__}.AutoClock"
    {:ok, _pid} = Clock.start_link(name: name, mode: :auto, start_time: DateTime.utc_now())

    assert Clock.mode(name) == :auto
    assert {:error, :auto_mode} = Clock.advance(name, 1_000)
    assert {:error, :auto_mode} = Clock.set_now(name, 0)
  end
end
