defmodule Beamulacrum.Ticker do
  use GenServer
  require Logger

  def start_link(_) do
    IO.puts("Starting ticker process...")

    case GenServer.start_link(__MODULE__, 0, name: __MODULE__) do
      {:ok, pid} ->
        IO.puts("Ticker started successfully with PID: #{inspect(pid)}")
        {:ok, pid}

      {:error, reason} ->
        IO.puts("Ticker failed to start: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def init(initial_tick) do
    IO.puts("Initializing ticker")
    schedule_tick()
    {:ok, initial_tick}
  end

  def handle_info(:tick, tick_number) do
    IO.puts("Now executing next tick")
    broadcast_tick(tick_number)
    schedule_tick()
    {:noreply, tick_number + 1}
  end

  defp schedule_tick() do
    tick_interval = Application.get_env(:beamulacrum, :simulation)[:tick_interval_ms] || 1000
    IO.puts("Scheduling next tick in #{tick_interval}ms")
    Process.send_after(self(), :tick, tick_interval)
  end

  defp broadcast_tick(tick_number) do
    actors =
      Registry.lookup(Beamulacrum.ActorRegistry, :actors) |> Enum.map(fn {pid, _} -> pid end)

    Enum.each(actors, fn actor_pid ->
      if Process.alive?(actor_pid) do
        IO.puts("Sending tick #{tick_number} to #{inspect(actor_pid)} (alive)")
        send(actor_pid, {:tick, tick_number})
      else
        IO.puts("Actor #{inspect(actor_pid)} is not alive!")
      end
    end)
  end
end
