defmodule Beamulator.ActorStatesProvider do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_call(:get_actor_states, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get_actor_state, actor_name}, _from, state) do
    {:reply, Map.get(state, actor_name), state}
  end

  def handle_cast({:update_actor_state, actor_state}, state) do
    new_state = Map.put(state, actor_state.name, actor_state)

    Logger.info("Updated actor state: #{inspect(actor_state.name)}")
    {:noreply, new_state}
  end

  def get_actor_states() do
    GenServer.call(__MODULE__, :get_actor_states)
  end

  def get_actor_state(actor_name) do
    GenServer.call(__MODULE__, {:get_actor_state, actor_name})
  end

  def update_actor_state(actor_state) do
    GenServer.cast(__MODULE__, {:update_actor_state, actor_state})
  end
end
