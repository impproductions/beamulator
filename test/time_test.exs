defmodule TimeTest do
  use ExUnit.Case

  alias Beamulator.Tools.Duration, as: D
  doctest Duration

  test "1 second in milliseconds" do
    assert D.new(s: 1) == 1_000
  end
end
