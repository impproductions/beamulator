defmodule Beamulator.Clock do
  alias Beamulator.Tools
  use GenServer
  require Logger

  def start_link(_) do
    Logger.debug("Starting clock process")
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_start_time() do
    GenServer.call(__MODULE__, :get_start_time)
  end

  def get_real_duration_ms() do
    GenServer.call(__MODULE__, :get_real_duration_ms)
  end

  def get_simulation_duration_ms() do
    GenServer.call(__MODULE__, :get_simulation_duration_ms)
  end

  def get_simulation_time_ms() do
    GenServer.call(__MODULE__, :get_simulation_time_ms)
  end

  def init(_) do
    start_time = DateTime.utc_now()

    Logger.info("Clock initialized at #{DateTime.to_iso8601(start_time)}")

    state = %{
      start_time: start_time
    }

    {:ok, state}
  end

  def handle_call(:get_real_duration_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, since_start, state}
  end

  def handle_call(:get_simulation_duration_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, Tools.Time.ms_to_simulation_ms(since_start), state}
  end

  # FIXME: same as above
  def handle_call(:get_simulation_time_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    simulation_ms = Tools.Time.ms_to_simulation_ms(since_start)

    {:reply, simulation_ms, state}
  end

  def handle_call(:get_start_time, _from, state) do
    {:reply, state.start_time, state}
  end
end
