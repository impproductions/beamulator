defmodule Beamulacrum.Ticker do
  use GenServer
  require Logger

  def start_link(_) do
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
    current_time = DateTime.utc_now()
    tick_number = state.tick_number

    broadcast_tick(state)

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

    Process.send_after(self(), :tick, tick_interval)
  end

  defp broadcast_tick(state) do
    tick_number = state.tick_number

    actors =
      Registry.lookup(Beamulacrum.ActorRegistry, :actors)
      |> Enum.map(fn {pid, _} -> pid end)

    actors
    |> Task.async_stream(
      fn actor_pid ->
        if Process.alive?(actor_pid) do
          GenServer.cast(actor_pid, {:tick, tick_number})
        end
      end,
      max_concurrency: 5,
      timeout: 5000
    )
    |> Stream.run()
  end
end
