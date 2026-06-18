defmodule Beamulator.Behaviors.Ping do
  alias Beamulator.Actions
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Behavior

  @impl true
  def default_tags(), do: MapSet.new(["role:ping"])

  @impl true
  def default_state(), do: %{counter: 0}

  @impl true
  def act(%{actor_state: state} = actor_data) do
    execute(actor_data, &Actions.noop/1, state.counter)
    new_state = %{state | counter: state.counter + 1}
    {:ok, D.new(s: 1), %{actor_data | actor_state: new_state}}
  end
end
