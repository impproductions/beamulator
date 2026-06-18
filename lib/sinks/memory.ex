defmodule Beamulator.Sinks.Memory do
  @behaviour Beamulator.Sinks.Sink
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_), do: {:ok, %{events: [], complaints: []}}

  def events(), do: GenServer.call(__MODULE__, :events)
  def complaints(), do: GenServer.call(__MODULE__, :complaints)
  def reset(), do: GenServer.call(__MODULE__, :reset)

  @impl true
  def log_event(%Beamulator.Sinks.Event{} = event) do
    GenServer.cast(__MODULE__, {:event, event})
    :ok
  end

  @impl true
  def log_complaint(%Beamulator.Sinks.Complaint{} = complaint) do
    GenServer.cast(__MODULE__, {:complaint, complaint})
    :ok
  end

  def handle_cast({:event, event}, state),
    do: {:noreply, %{state | events: [event | state.events]}}

  def handle_cast({:complaint, complaint}, state),
    do: {:noreply, %{state | complaints: [complaint | state.complaints]}}

  def handle_call(:events, _from, state), do: {:reply, Enum.reverse(state.events), state}
  def handle_call(:complaints, _from, state), do: {:reply, Enum.reverse(state.complaints), state}
  def handle_call(:reset, _from, _state), do: {:reply, :ok, %{events: [], complaints: []}}
end
