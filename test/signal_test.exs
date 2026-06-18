defmodule Beamulator.Lab.SignalTest do
  use ExUnit.Case

  alias Beamulator.Lab.Signal

  test "default sine fits in period" do
    assert_in_delta Signal.sine(0, 0), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 1250), 0.7071, 0.0001
    assert_in_delta Signal.sine(0, 2500), 1.0, 0.0001
    assert_in_delta Signal.sine(0, 3750), 0.7071, 0.0001
    assert_in_delta Signal.sine(0, 5000), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 6250), -0.7071, 0.0001
    assert_in_delta Signal.sine(0, 7500), -1.0, 0.0001
    assert_in_delta Signal.sine(0, 8750), -0.7071, 0.0001
    assert_in_delta Signal.sine(0, 10_000), 0.0, 0.0001
  end

  test "custom amplitude" do
    assert_in_delta Signal.sine(0, 0, 2), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 1250, 2), 1.4142, 0.0001
    assert_in_delta Signal.sine(0, 2500, 2), 2.0, 0.0001
    assert_in_delta Signal.sine(0, 3750, 2), 1.4142, 0.0001
    assert_in_delta Signal.sine(0, 5000, 2), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 6250, 2), -1.4142, 0.0001
    assert_in_delta Signal.sine(0, 7500, 2), -2.0, 0.0001
    assert_in_delta Signal.sine(0, 8750, 2), -1.4142, 0.0001
    assert_in_delta Signal.sine(0, 10_000, 2), 0.0, 0.0001
  end

  test "custom period" do
    assert_in_delta Signal.sine(0, 0, 1, 5000), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 1250, 1, 5000), 1.0, 0.0001
    assert_in_delta Signal.sine(0, 2500, 1, 5000), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 3750, 1, 5000), -1.0, 0.0001
    assert_in_delta Signal.sine(0, 5000, 1, 5000), 0.0, 0.0001
  end

  test "custom phase" do
    assert_in_delta Signal.sine(0, 0, 1, 10_000, :math.pi() / 2), 1.0, 0.0001
    assert_in_delta Signal.sine(0, 2500, 1, 10_000, :math.pi() / 2), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 5000, 1, 10_000, :math.pi() / 2), -1.0, 0.0001
    assert_in_delta Signal.sine(0, 7500, 1, 10_000, :math.pi() / 2), 0.0, 0.0001
    assert_in_delta Signal.sine(0, 10_000, 1, 10_000, :math.pi() / 2), 1.0, 0.0001
  end

  test "offset shifts the whole signal" do
    assert_in_delta Signal.sine(3.0, 0), 3.0, 0.0001
    assert_in_delta Signal.sine(3.0, 2500), 4.0, 0.0001
    assert_in_delta Signal.sine(3.0, 7500), 2.0, 0.0001
  end
end
