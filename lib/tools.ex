defmodule Beamulator.Tools do
  def increasing_int() do
    :erlang.unique_integer([:monotonic, :positive])
  end

  def random_int(min, max) do
    :rand.uniform(max - min) + min
  end

  def random_seed() do
    Application.get_env(:beamulator, :simulation)[:random_seed]
  end

  defmodule Actors do
    def get_state(pid) do
      case Registry.lookup(Beamulator.ActorRegistry, :actors)
           |> Enum.find(fn {p_id, _} -> pid == p_id end) do
        {pid, _} ->
          GenServer.call(pid, :state)
        _ ->
          {:error, "Actor not found"}
      end
    end

    def select_by_behavior(behavior_module) do
      Registry.match(Beamulator.ActorRegistry, :actors, {behavior_module, :_, :_})
    end

    def select_by_name(name) do
      Registry.match(Beamulator.ActorRegistry, :actors, {:_, :_, name})
    end
  end

  defmodule Time do
    def second() do
      Application.get_env(:beamulator, :simulation)[:tick_to_seconds]
    end

    def minute() do
      60 * second()
    end

    def hour() do
      60 * minute()
    end

    def day() do
      24 * hour()
    end

    def week() do
      7 * day()
    end

    def month() do
      30 * day()
    end

    def year() do
      365 * day()
    end

    def tick_interval_ms() do
      Application.get_env(:beamulator, :simulation)[:tick_interval_ms]
    end

    def time_speed_multiplier() do
      1000 / tick_interval_ms()
    end

    def tick_to_ms(tick) do
      tick * tick_interval_ms()
    end

    def ms_to_tick(time) do
      div(time, tick_interval_ms())
    end

    def as_duration_human(tick) when is_integer(tick) do
      duration = Timex.Duration.from_seconds(tick)

      duration
      |> Timex.Format.Duration.Formatter.format(:humanized)
      |> String.replace(" ago", "")
    end

    def as_duration_human(tick, :shorten) when is_integer(tick) do
      as_duration_human(tick)
      |> String.split(", ")
      |> Enum.map(fn part ->
        [amt, unit] = String.split(part, " ")

        cond do
          String.starts_with?(unit, "mic") -> "#{amt}μs"
          String.starts_with?(unit, "mil") -> "#{amt}ms"
          String.starts_with?(unit, "sec") -> "#{amt}s"
          String.starts_with?(unit, "min") -> "#{amt}m"
          String.starts_with?(unit, "hou") -> "#{amt}h"
          String.starts_with?(unit, "day") -> "#{amt}d"
          String.starts_with?(unit, "wee") -> "#{amt}w"
          String.starts_with?(unit, "mon") -> "#{amt}M"
          String.starts_with?(unit, "yea") -> "#{amt}y"
        end
      end)
      |> Enum.join("")
    end
  end
end
