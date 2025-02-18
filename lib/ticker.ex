defmodule Beamulacrum.Ticker do
  use GenServer

  # 1 second per tick
  @tick_interval 1000

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
    IO.puts("Scheduling tick")
    Process.send_after(self(), :tick, @tick_interval)
  end

  defp broadcast_tick(tick_number) do
    actors =
      Registry.lookup(Beamulacrum.ActorRegistry, :actors) |> Enum.map(fn {pid, _} -> pid end)

    Enum.each(actors, fn actor_pid ->
      IO.puts("Sending tick #{tick_number} to #{inspect(actor_pid)}")
      send(actor_pid, {:tick, tick_number})
    end)

    IO.puts("Broadcasted tick #{tick_number} to #{length(actors)} actors")
  end
end
