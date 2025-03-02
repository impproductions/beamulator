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
    alias Beamulator.Tools.Duration
    def time_speed_multiplier() do
      Application.get_env(:beamulator, :simulation)[:time_speed_multiplier]
    end

    def simulation_ms_to_ms(simulation_ms) do
      div(simulation_ms, time_speed_multiplier())
    end

    def ms_to_simulation_ms(time) do
      time * time_speed_multiplier()
    end

    def as_duration_human(time_ms) when is_integer(time_ms) do
      Duration.new(ms: time_ms)
      |> Duration.to_string()
    end

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
      |> Enum.join("")
    end
  end
end
