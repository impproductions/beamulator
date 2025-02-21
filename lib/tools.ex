defmodule Beamulacrum.Tools do
  def increasing_int() do
    :erlang.unique_integer([:monotonic, :positive])
  end

  def random_int(min, max) do
    :rand.uniform(max - min) + min
  end

  def random_seed() do
    Application.get_env(:beamulacrum, :simulation)[:random_seed]
  end

  defmodule Logging do
    require Logger

    def log(level, message) do
      Logger.log(level, message)
    end
  end

  defmodule Actors do
    def select_by_behavior(behavior_module) do
      Registry.match(Beamulacrum.ActorRegistry, :actors, {behavior_module, :_, :_})
    end
  end

  defmodule Time do
    def second() do
      1 * Application.get_env(:beamulacrum, :simulation)[:tick_to_seconds]
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
      Application.get_env(:beamulacrum, :simulation)[:tick_interval_ms]
    end

    def time_speed_multiplier() do
      1000 / tick_interval_ms()
    end

    def as_duration(tick) when is_integer(tick) do
      duration = Timex.Duration.from_seconds(tick)

      duration
      |> Timex.Format.Duration.Formatter.format(:humanized)
      |> String.replace(" ago", "")
    end

    def as_duration(tick, :shorten) when is_integer(tick) do
      as_duration(tick)
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
