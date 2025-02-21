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

  defmodule Manage do
    def list_behaviors() do
      Beamulacrum.Behavior.Registry.list_behaviors()
    end

    def list_actors() do
      Registry.lookup(Beamulacrum.ActorRegistry, :actors)
      |> Enum.map(fn {pid, {behavior, serial_id, name}} ->
        "#{name} (#{behavior}) (#{serial_id}) [#{inspect(pid)}]"
      end)
    end

    def actor_state(pid_string) when is_binary(pid_string) do
      pid_string =
        if String.starts_with?(pid_string, "#PID") do
          String.slice(pid_string, 4..-1//1)
        else
          pid_string
        end

      p_id = pid_string |> String.to_charlist() |> :erlang.list_to_pid()

      case Registry.lookup(Beamulacrum.ActorRegistry, :actors)
           |> Enum.find(fn {pid, _} -> pid == p_id end) do
        {pid, {behavior, serial_id, name}} ->
          actor_state = GenServer.call(pid, :state)

          IO.puts("""
          Actor #{name} (#{behavior}) (#{serial_id}) [#{inspect(pid)}]
          State: #{inspect(actor_state, pretty: true, syntax_colors: [number: :red, atom: :cyan, string: :green, identifier: :blue])}
          """)
          :ok
        _ ->
          "Actor not found"
      end
    end

    def spawn_actor(behavior_module) do
      behaviour_name = behavior_module |> Atom.to_string() |> String.split(".") |> List.last()
      name = "#{behaviour_name} #{Beamulacrum.Tools.increasing_int()}"
      spawn_actor(name, behavior_module, %{})
    end

    def spawn_actor(name, behavior_module) do
      spawn_actor(name, behavior_module, %{})
    end

    def spawn_actor(name, behavior_module, config) do
      IO.puts(
        "Spawning actor #{name} with behavior #{inspect(behavior_module)} and config #{inspect(config)}"
      )

      Beamulacrum.ActorSupervisor.start_actor(name, behavior_module, config)
    end

    def kill_actor(pid_string) when is_binary(pid_string) do
      pid_string =
        if String.starts_with?(pid_string, "#PID") do
          String.slice(pid_string, 4..-1//1)
        else
          pid_string
        end

      IO.puts("Killing actor with PID #{pid_string}")
      pid = pid_string |> String.to_charlist() |> :erlang.list_to_pid()

      DynamicSupervisor.terminate_child(Beamulacrum.ActorSupervisor, pid)
    end
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
      Application.get_env(:beamulacrum, :simulation)[:tick_to_seconds]
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
