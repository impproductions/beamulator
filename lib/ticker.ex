defmodule Beamulacrum.Ticker do
  alias Beamulacrum.Tools
  use GenServer
  require Logger

  def start_link(_) do
    Logger.debug("Starting ticker process")
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_start_time() do
    GenServer.call(__MODULE__, :get_start_time)
  end

  def get_tick_number() do
    GenServer.call(__MODULE__, :get_tick_number)
  end

  def get_fps() do
    GenServer.call(__MODULE__, :get_fps)
  end

  def init(_) do
    start_time = DateTime.utc_now()

    Logger.info("Ticker initialized at #{DateTime.to_iso8601(start_time)}")

    schedule_tick()

    state = %{
      tick_number: 0,
      start_time: start_time,
      fps_counter: 0,
      last_fps_time: start_time,
      last_fps: 0
    }

    {:ok, state}
  end

  def handle_info(:tick, state) do
    tick_interval =
      Tools.Time.tick_interval_ms() || 1000

    if rem(state.tick_number, div(1000, tick_interval)) == 0 do
      Logger.info("Tick #{state.tick_number} (#{Tools.Time.as_duration(state.tick_number)})")
    end

    current_time = DateTime.utc_now()
    tick_number = state.tick_number

    broadcast_tick_through_pg(state)
    # broadcast_tick(state)

    new_fps_counter = state.fps_counter + 1
    {updated_fps, updated_fps_counter, updated_last_fps_time} =
      if DateTime.diff(current_time, state.last_fps_time, :second) >= 1 do
        {new_fps_counter, 0, current_time}
      else
        {state.last_fps, new_fps_counter, state.last_fps_time}
      end

    schedule_tick()

    new_state = %{
      state
      | tick_number: tick_number + 1,
        fps_counter: updated_fps_counter,
        last_fps_time: updated_last_fps_time,
        last_fps: updated_fps
    }

    Logger.debug("Tick #{tick_number + 1} processed")

    {:noreply, new_state}
  end

  def handle_call(:get_tick_number, _from, state) do
    {:reply, state.tick_number, state}
  end

  def handle_call(:get_start_time, _from, state) do
    {:reply, state.start_time, state}
  end

  def handle_call(:get_fps, _from, state) do
    {:reply, state.last_fps, state}
  end

  defp schedule_tick() do
    tick_interval =
      Application.get_env(:beamulacrum, :simulation)[:tick_interval_ms] || 1000

    Logger.debug("Scheduling next tick in #{tick_interval}ms")
    Process.send_after(self(), :tick, tick_interval)
  end

  defp broadcast_tick(state) do
    tick_number = state.tick_number

    actors =
      Registry.lookup(Beamulacrum.ActorRegistry, :actors)
      |> Enum.map(fn {pid, _} -> pid end)

    if Enum.empty?(actors) do
      Logger.warning("No actors found to receive tick #{tick_number}")
    else
      Logger.debug("Broadcasting tick #{tick_number} to #{length(actors)} actors")
    end

    actors
    |> Task.async_stream(
      fn actor_pid ->
        if Process.alive?(actor_pid) do
          GenServer.cast(actor_pid, {:tick, tick_number})
        else
          Logger.warning("Actor process #{inspect(actor_pid)} is not alive during tick #{tick_number}")
        end
      end,
      max_concurrency: 5,
      timeout: 5000
    )
    |> Stream.run()
  end

  defp broadcast_tick_through_pg(state) do
    tick_number = state.tick_number

    Beamulacrum.ActorProcessGroup.broadcast({:tick, tick_number})
  end
end
