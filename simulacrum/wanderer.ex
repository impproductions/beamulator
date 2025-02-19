defmodule Beamulacrum.Behaviors.Wanderer do
  @behaviour Beamulacrum.Behavior

  alias Beamulacrum.ActionExecutor
  # alias Beamulacrum.Behaviors
  alias Beamulacrum.Actions

  @impl Beamulacrum.Behavior
  def default_state(), do: %{x: 0, y: 0}

  @impl Beamulacrum.Behavior
  def act(tick, %{name: name, state: state, config: config} = data) do
    multiplier = case tick do
      tick when tick < 10 -> 1
      tick when tick < 20 -> 10
      tick when tick < 30 -> 50
      _ -> 100
    end
    dx = Enum.random([-multiplier * config.speed, 0, multiplier * config.speed])
    dy = Enum.random([-multiplier * config.speed, 0, multiplier * config.speed])

    _ = ActionExecutor.exec(&Actions.move/1, %{name: name, dx: dx, dy: dy})

    new_data = %{data | state: %{state | x: state.x + dx, y: state.y + dy}}

    IO.puts("Actor #{name} moved to (#{new_data.state.x}, #{new_data.state.y})")
    {:ok, new_data}
  end
end
