defmodule Beamulator.Tools.Signal do
  def normal(offset \\ 0, mean \\ 0, variance \\ 1) do
    offset + :rand.normal(mean, variance)
  end

  def sine(offset, time_ms, amplitude \\ 1, period_ms \\ 10_000, phase_rad \\ 0) do
    offset + :math.sin(2 * :math.pi() * time_ms / period_ms + phase_rad) * amplitude
  end

  def square(offset, time_ms, amplitude \\ 1, period_ms \\ 10_000, duty_cycle \\ 0.5) do
    phase = rem(time_ms, trunc(period_ms))
    signal = if phase < duty_cycle * period_ms, do: amplitude, else: -amplitude
    offset + signal
  end

  def triangle(offset, time_ms, amplitude \\ 10_000, period_ms \\ 1) do
    phase = rem(time_ms, trunc(period_ms))
    fraction = phase / period_ms
    value = if fraction < 0.5, do: fraction * 2 * amplitude, else: (1 - fraction) * 2 * amplitude
    offset + value
  end

  def sawtooth(offset, time_ms, amplitude \\ 10_000, period_ms \\ 1) do
    phase = rem(time_ms, trunc(period_ms))
    fraction = phase / period_ms
    value = -amplitude + fraction * (2 * amplitude)
    offset + value
  end

  def pulse(offset, time_ms, amplitude \\ 1, period_ms \\ 10_000, pulse_width \\ 0.5) do
    phase = rem(time_ms, trunc(period_ms))
    signal = if phase < pulse_width * period_ms, do: amplitude, else: -amplitude
    offset + signal
  end

  def patch(offset, patch_pid) do
    simulation_now = Beamulator.Clock.get_simulation_now()

    case Beamulator.Tools.Signal.Patch.get(patch_pid, offset, simulation_now) do
      {:ok, res} -> res
      error -> error
    end
  end

  def patch!(offset, patch_pid) do
    simulation_now = Beamulator.Clock.get_simulation_now()
    Beamulator.Tools.Signal.Patch.get!(patch_pid, offset, simulation_now)
  end
end

defmodule Beamulator.Tools.Signal.Patch.Config do
  @enforce_keys [:adjustment_fn]
  defstruct duration: 0, adjustment_fn: nil
end

defmodule Beamulator.Tools.Signal.Patch do
  alias Beamulator.Tools
  use GenServer
  require Logger

  def create(config) do
    {:ok, pid} = GenServer.start_link(__MODULE__, config)
    pid
  end

  def start(pid, now, duration), do: GenServer.cast(pid, {:start, now, duration})
  def get(pid, base, now), do: GenServer.call(pid, {:get, base, now})

  def get!(pid, base, now) do
    case get(pid, base, now) do
      {:ok, res} -> res
      {:error, reason} -> raise "Patch error: #{inspect(reason)}"
    end
  end

  def init(config) do
    state = Map.merge(%{status: :idle, start_ms: nil, value: 0}, config)
    {:ok, state}
  end

  def handle_cast({:start, now, duration}, state) do
    if state.status != :active do
      real_duration = Tools.Time.simulation_ms_to_ms(duration)
      new_state = %{state | status: :active, start_ms: now, duration: duration}
      Process.send_after(self(), :finish, real_duration)
      {:noreply, new_state}
    else
      Logger.warning("Patch #{inspect(self())} already started, ignoring")
      {:noreply, state}
    end
  end

  def handle_info(:finish, state) do
    final_value = state.adjustment_fn.(state.duration, state.duration)
    {:noreply, %{state | status: :finished, value: final_value}}
  end

  def handle_call({:get, base, now}, _from, state) do
    res =
      case state.status do
        :active ->
          elapsed = now - state.start_ms

          if elapsed <= state.duration,
            do: state.adjustment_fn.(elapsed, state.duration),
            else: state.adjustment_fn.(state.duration, state.duration)

        :finished ->
          0

        _ ->
          0
      end

    reply = if is_number(res), do: {:ok, base + res}, else: res
    {:reply, reply, state}
  end
end

defmodule Beamulator.Tools.Signal.PatchPresets do
  alias Beamulator.Tools.Signal
  alias Beamulator.Tools.Signal.Patch.Config
  require Logger

  def ramp(final_value) do
    Signal.Patch.create(%Config{
      adjustment_fn: fn elapsed, duration ->
        res = final_value * (elapsed / duration)
        Logger.info("Ramp: #{res}, elapsed: #{elapsed}, duration: #{duration}")
        res
      end
    })
  end

  def slope(final_value) do
    Signal.Patch.create(%Config{
      adjustment_fn: fn elapsed, duration ->
        res = -(final_value * (elapsed / duration))
        Logger.info("Slope: #{res}, elapsed: #{elapsed}, duration: #{duration}")
        res
      end
    })
  end

  def peak(max_value) do
    Signal.Patch.create(%Config{
      adjustment_fn: fn elapsed, duration ->
        half = duration / 2

        if elapsed <= half do
          max_value * (elapsed / half)
        else
          max_value * (1 - (elapsed - half) / half)
        end
      end
    })
  end

  def pulse(max_value) do
    Signal.Patch.create(%Config{
      adjustment_fn: fn elapsed, duration -> if elapsed < duration, do: max_value, else: 0 end
    })
  end

  def dip(min_value) do
    Signal.Patch.create(%Config{
      adjustment_fn: fn elapsed, duration ->
        half = duration / 2

        if elapsed <= half do
          min_value * (elapsed / half)
        else
          min_value * (1 - (elapsed - half) / half)
        end
      end
    })
  end
end
