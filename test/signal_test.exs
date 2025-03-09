defmodule DurationTest do
  use ExUnit.Case

  alias Beamulator.Utils.Signal
  doctest Duration

  test "default sine fits in period" do
    assert_in_delta Signal.sine(0), 0.0, 0.0001
    assert_in_delta Signal.sine(125), 0.7071, 0.0001
    assert_in_delta Signal.sine(250), 1.0, 0.0001
    assert_in_delta Signal.sine(375), 0.7071, 0.0001
    assert_in_delta Signal.sine(500), 0.0, 0.0001
    assert_in_delta Signal.sine(625), -0.7071, 0.0001
    assert_in_delta Signal.sine(750), -1.0, 0.0001
    assert_in_delta Signal.sine(875), -0.7071, 0.0001
    assert_in_delta Signal.sine(1000), 0.0, 0.0001
  end

  test "custom amplitude" do
    assert_in_delta Signal.sine(0, 2), 0.0, 0.0001
    assert_in_delta Signal.sine(125, 2), 1.4142, 0.0001
    assert_in_delta Signal.sine(250, 2), 2.0, 0.0001
    assert_in_delta Signal.sine(375, 2), 1.4142, 0.0001
    assert_in_delta Signal.sine(500, 2), 0.0, 0.0001
    assert_in_delta Signal.sine(625, 2), -1.4142, 0.0001
    assert_in_delta Signal.sine(750, 2), -2.0, 0.0001
    assert_in_delta Signal.sine(875, 2), -1.4142, 0.0001
    assert_in_delta Signal.sine(1000, 2), 0.0, 0.0001
  end

  test "custom period" do
    assert_in_delta Signal.sine(0, 1, 5), 0.0, 0.0001
    assert_in_delta Signal.sine(1250, 1, 5), 1.0, 0.0001
    assert_in_delta Signal.sine(2500, 1, 5), 0.0, 0.0001
    assert_in_delta Signal.sine(3750, 1, 5), -1.0, 0.0001
    assert_in_delta Signal.sine(5000, 1, 5), 0.0, 0.0001
  end

  test "custom phase" do
    assert_in_delta Signal.sine(0, 1, 1, :math.pi() / 2), 1.0, 0.0001
    assert_in_delta Signal.sine(250, 1, 1, :math.pi() / 2), 0.0, 0.0001
    assert_in_delta Signal.sine(500, 1, 1, :math.pi() / 2), -1.0, 0.0001
    assert_in_delta Signal.sine(750, 1, 1, :math.pi() / 2), 0.0, 0.0001
    assert_in_delta Signal.sine(1000, 1, 1, :math.pi() / 2), 1.0, 0.0001
  end
end
