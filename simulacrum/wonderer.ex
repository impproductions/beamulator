defmodule Wanderer do
  @behaviour Beamulacrum.Behavior

  @impl Beamulacrum.Behavior
  def default_state(), do: %{x: 0, y: 0}

  @impl Beamulacrum.Behavior
  def decide(state) do
    dx = Enum.random([-1, 0, 1])
    dy = Enum.random([-1, 0, 1])

    new_state = %{state | x: state.x + dx, y: state.y + dy}
    IO.puts("Wanderer moves to (#{new_state.x}, #{new_state.y})")

    {:move, new_state}
  end
end
