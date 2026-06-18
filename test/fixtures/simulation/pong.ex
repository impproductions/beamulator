defmodule Beamulator.Roles.Pong do
  alias Beamulator.Actions
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Role

  @impl true
  def default_tags(), do: MapSet.new(["role:pong"])

  @impl true
  def default_state(), do: %{received: []}

  @impl true
  def act(%{actor_state: state} = actor_data) do
    execute(actor_data, &Actions.noop/1, length(state.received))
    {:ok, D.new(s: 2), actor_data}
  end
end
