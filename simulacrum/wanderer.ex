defmodule Beamulacrum.Behaviors.Wanderer do
  @behaviour Beamulacrum.Behavior

  alias Beamulacrum.ActionExecutor
  # alias Beamulacrum.Behaviors
  alias Beamulacrum.Actions

  @impl Beamulacrum.Behavior
  def default_state(), do: %{x: 0, y: 0}

  @impl Beamulacrum.Behavior
  def act(tick, %{name: name, data: data} = state) do
    multiplier = case tick do
      tick when tick < 10 -> 1
      tick when tick < 20 -> 10
      tick when tick < 30 -> 50
      _ -> 100
    end
    dx = Enum.random([-multiplier, 0, multiplier])
    dy = Enum.random([-multiplier, 0, multiplier])

    _ = ActionExecutor.exec(&Actions.move/1, %{name: name, dx: dx, dy: dy})

    new_state = %{state | data: %{data | x: data.x + dx, y: data.y + dy}}

    IO.puts("Actor #{name} moved to (#{new_state.data.x}, #{new_state.data.y})")
    {:ok, new_state}
  end
end
