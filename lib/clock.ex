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

  @spec get_simulation_now() :: any()
  def get_simulation_now() do
    GenServer.call(__MODULE__, :get_simulation_now)
  end

  def get_simulation_duration_ms() do
    GenServer.call(__MODULE__, :get_simulation_duration_ms)
  end

  def init(_) do
    start_time =
      if Application.get_env(:beamulator, :start_time) do
        Application.get_env(:beamulator, :start_time)
      else
        DateTime.utc_now()
      end

    Application.put_env(:beamulator, :start_time, start_time)

    Logger.info("Clock initialized at #{DateTime.to_iso8601(start_time)}")

    state = %{
      start_time: start_time
    }

    {:ok, state}
  end

  def handle_call(:get_simulation_now, _from, state) do
    start_time = state.start_time
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)

    simulation_now =
      DateTime.to_unix(start_time, :millisecond) + Tools.Time.ms_to_simulation_ms(since_start)

    {:reply, simulation_now, state}
  end

  def handle_call(:get_real_duration_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, since_start, state}
  end

  def handle_call(:get_simulation_duration_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, Tools.Time.ms_to_simulation_ms(since_start), state}
  end

  def handle_call(:get_start_time, _from, state) do
    {:reply, state.start_time, state}
  end
end
