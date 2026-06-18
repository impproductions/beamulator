defmodule Beamulator.Clients.QuestDBFake do
  @behaviour Beamulator.Clients.QuestDB
  use GenServer

  def start_link(_ \\ []), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_), do: {:ok, %{posted: [], execs: []}}

  def posted_lines(), do: GenServer.call(__MODULE__, :posted)
  def execs(), do: GenServer.call(__MODULE__, :execs)
  def reset(), do: GenServer.call(__MODULE__, :reset)

  @impl true
  def test_connection(_url), do: :ok

  @impl true
  def exec(_url, query) do
    GenServer.call(__MODULE__, {:exec, query})
  end

  @impl true
  def write(_url, payload) do
    GenServer.call(__MODULE__, {:write, payload})
  end

  def handle_call({:write, payload}, _from, state),
    do: {:reply, :ok, %{state | posted: state.posted ++ [payload]}}

  def handle_call({:exec, query}, _from, state),
    do: {:reply, :ok, %{state | execs: state.execs ++ [query]}}

  def handle_call(:posted, _from, state), do: {:reply, state.posted, state}
  def handle_call(:execs, _from, state), do: {:reply, state.execs, state}
  def handle_call(:reset, _from, _state), do: {:reply, :ok, %{posted: [], execs: []}}
end
