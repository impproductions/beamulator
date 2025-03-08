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
    alias Beamulator.Actor

    @spec get_state(pid :: pid()) :: Actor.Data.t() | {:error, String.t()}
    def get_state(pid) when is_pid(pid) do
      case Registry.lookup(Beamulator.ActorRegistry, :actors)
           |> Enum.find(fn {p_id, _} -> pid == p_id end) do
        {pid, _} ->
          GenServer.call(pid, :state)

        _ ->
          {:error, "Actor not found"}
      end
    end

    @spec get_state(serial_id :: integer()) :: Actor.Data.t() | {:error, String.t()}
    def get_state(serial_id) when is_integer(serial_id) do
      case select_by_serial_id(serial_id) do
        {:error, _} ->
          {:error, "Actor not found"}

        {pid, _} ->
          GenServer.call(pid, :state)
      end
    end

    @spec select_all() :: [
            {pid(), {behavior :: module(), serial_id :: integer(), name :: binary()}}
          ]
    def select_all() do
      Registry.lookup(Beamulator.ActorRegistry, :actors)
    end

    @spec select_by_pid(pid()) ::
            {pid(), {behavior :: module(), serial_id :: integer(), name :: binary()}}
            | {:error, String.t()}
    def select_by_pid(pid) when is_pid(pid) do
      Registry.lookup(Beamulator.ActorRegistry, :actors)
      |> Enum.find(fn {p_id, _} -> pid == p_id end) || {:error, "Actor not found"}
    end

    @spec select_by_behavior(module()) :: [
            {pid(), {behavior :: module(), serial_id :: integer(), name :: binary()}}
          ]
    def select_by_behavior(behavior_module) when is_atom(behavior_module) do
      Registry.match(Beamulator.ActorRegistry, :actors, {behavior_module, :_, :_})
    end

    @spec select_by_name(binary()) :: [{pid(), any()}]
    def select_by_name(name) when is_binary(name) do
      Registry.match(Beamulator.ActorRegistry, :actors, {:_, :_, name})
    end

    @spec select_by_serial_id(integer()) ::
            {pid(), {behavior :: module(), serial_id :: integer(), name :: binary()}}
            | {:error, String.t()}
    def select_by_serial_id(serial_id) when is_integer(serial_id) do
      Registry.match(Beamulator.ActorRegistry, :actors, {:_, serial_id, :_})
      |> Enum.at(0) || {:error, "Actor not found"}
    end
  end

  defmodule Time do
    alias Beamulator.Clock
    alias Beamulator.Tools.Duration

    def time_speed_multiplier() do
      Application.get_env(:beamulator, :simulation)[:time_speed_multiplier]
    end

    @spec simulation_ms_to_ms(integer()) :: integer()
    def simulation_ms_to_ms(simulation_ms) when is_integer(simulation_ms) do
      div(simulation_ms, time_speed_multiplier())
    end

    @spec ms_to_simulation_ms(integer()) :: integer()
    def ms_to_simulation_ms(time) when is_integer(time) do
      time * time_speed_multiplier()
    end

    @spec simulation_time_after!(time_ms :: integer()) :: DateTime.t()
    def simulation_time_after!(time_ms) do
      (Clock.get_simulation_now() + time_ms)
      |> DateTime.from_unix!(:millisecond)
    end

    @spec real_time_after!(simulation_time_ms :: integer()) :: DateTime.t()
    def real_time_after!(simulation_time_ms) do
      ((DateTime.utc_now() |> DateTime.to_unix(:millisecond)) +
         simulation_ms_to_ms(simulation_time_ms))
      |> DateTime.from_unix!(:millisecond)
    end

    # TODO allow different time resolutions
    @spec adjust_to_time_window(
            time_to_wait_ms :: integer(),
            from_hour :: non_neg_integer(),
            to_hour :: non_neg_integer()
          ) :: integer()
    def adjust_to_time_window(to_wait, from, to) do
      # FIXME remove dependency and unit test
      next_action_simulation_time = simulation_time_after!(to_wait)
      next_action_hour = Map.get(next_action_simulation_time, :hour)

      # upper limit is exclusive, you don't want to be working at 17:30 if your day ends at 17:00
      limit = to - 1

      cond do
        next_action_hour in from..limit ->
          to_wait

        next_action_hour < from ->
          to_wait + Duration.new(h: from - next_action_hour)

        true ->
          to_wait + Duration.new(h: from + 24 - next_action_hour)
      end
    end

    @spec adjust_to_time_window(
            time_to_wait_ms :: integer(),
            from_hour :: non_neg_integer(),
            to_hour :: non_neg_integer(),
            offset_hours :: integer()
          ) :: integer()
    def adjust_to_time_window(to_wait, from, to, offset) do
      adjust_to_time_window(to_wait, from, to) + Duration.new(h: offset)
    end

    @spec as_duration_human(non_neg_integer()) :: binary()
    def as_duration_human(time_ms) when is_integer(time_ms) do
      Duration.new(ms: time_ms)
      |> Duration.to_string()
    end

    @spec as_duration_human(non_neg_integer(), :shorten) :: binary()
    def as_duration_human(time_ms, :shorten) when is_integer(time_ms) do
      as_duration_human(time_ms)
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
        end
      end)
      |> Enum.join(", ")
    end
  end
end
