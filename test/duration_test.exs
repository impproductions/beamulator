defmodule DurationTest do
  use ExUnit.Case

  alias Beamulator.Tools.Duration, as: D
  doctest Duration

  test "1 second in milliseconds" do
    assert D.new(s: 1) == 1_000
  end

  test "1 hour in milliseconds" do
    assert D.new(h: 1) == 3_600_000
  end

  test "1 day in milliseconds" do
    assert D.new(d: 1) == 86_400_000
  end

  test "1 week in milliseconds" do
    assert D.new(w: 1) == 86_400_000 * 7
  end

  test "1 week, 1 day, 1 hour, 1 minute, 1 second in milliseconds" do
    assert D.new(w: 1, d: 1, h: 1, m: 1, s: 1) == 8 * 86_400_000 + 3_600_000 + 60_000 + 1_000
  end

  test "1 week, 1 day, 1 hour, 1 minute, 1 second in humanized format" do
    assert D.new(w: 1, d: 1, h: 1, m: 1, s: 1)
           |> D.to_string() == "1 week, 1 day, 1 hour, 1 minute, 1 second"
  end

  test "5 weeks, 4 days, 14 hours, 23 minutes, 59 seconds in humanized format" do
    assert D.new(w: 5, d: 4, h: 14, m: 23, s: 59)
           |> D.to_string() == "5 weeks, 4 days, 14 hours, 23 minutes, 59 seconds"
  end

  test "1 year, 1 day in humanized format" do
    assert D.new(w: 52, d: 1)
           |> D.to_string() == "52 weeks, 1 day"
  end
end
