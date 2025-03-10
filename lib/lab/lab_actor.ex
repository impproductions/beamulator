defmodule ActorDefinition do
  @enforce_keys [:behavior, :name, :pid, :serial_id]
  defstruct [:behavior, :name, :pid, :serial_id]

  @type t :: %__MODULE__{
          pid: pid(),
          behavior: module(),
          name: String.t(),
          serial_id: non_neg_integer()
        }
end

defmodule Beamulator.Lab.Actor do
  alias Beamulator.Utils

  def get_state!(pid) when is_pid(pid) do
    case get_state(pid) do
      {:ok, state} -> state
      {:error, reason} -> raise "Actor not found: #{inspect(reason)}"
    end
  end

  def get_state!(serial_id) when is_integer(serial_id) do
    case get_state(serial_id) do
      {:ok, state} -> state
      {:error, reason} -> raise "Actor not found: #{inspect(reason)}"
    end
  end

  def get_state(pid) when is_pid(pid) do
    case Utils.Actors.get_state(pid) do
      state when is_map(state) -> {:ok, state}
      {:error, reason} -> {:error, "Actor not found: #{inspect(reason)}"}
    end
  end

  def get_state(serial_id) when is_integer(serial_id) do
    case Utils.Actors.get_state(serial_id) do
      state when is_map(state) -> {:ok, state}
      {:error, reason} -> {:error, "Actor not found: #{inspect(reason)}"}
    end
  end

  def set_tags(pid, tags) do
    GenServer.cast(pid, {:set_tags, tags})
  end

  def select_all() do
    Utils.Actors.select_all()
    |> Enum.map(&as_actor_definition/1)
  end

  def select_by_pid(pid) do
    Utils.Actors.select_by_pid(pid)
    |> as_actor_definition()
  end

  def select_by_behavior(behavior_module) do
    Utils.Actors.select_by_behavior(behavior_module)
    |> Enum.map(&as_actor_definition/1)
  end

  def select_by_name(name) do
    Utils.Actors.select_by_name(name)
    |> Enum.map(&as_actor_definition/1)
  end

  def select_by_serial_id(serial_id) do
    Utils.Actors.select_by_serial_id(serial_id)
    |> as_actor_definition()
  end

  def filter_by_tag(actors, tag) do
    actors
    |> Stream.filter(fn %{pid: pid} ->
      get_state!(pid)
      |> Map.get(:tags)
      |> MapSet.member?(tag)
    end)
  end

  defp as_actor_definition({pid, {behavior, serial_id, name}}) do
    %ActorDefinition{behavior: behavior, name: name, pid: pid, serial_id: serial_id}
  end
end
