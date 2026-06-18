defmodule ActorDefinition do
  @enforce_keys [:role, :name, :pid, :serial_id]
  defstruct [:role, :name, :pid, :serial_id]

  @type t :: %__MODULE__{
          pid: pid(),
          role: module(),
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

  def invoke(serial_id, action_name, args) when is_integer(serial_id) do
    case Utils.Actors.select_by_serial_id(serial_id) do
      {pid, _} when is_pid(pid) -> invoke(pid, action_name, args)
      _ -> {:error, :actor_not_found}
    end
  end

  def invoke(pid, action_name, args) when is_pid(pid) do
    GenServer.call(pid, {:invoke_action, action_name, args}, 10_000)
  end

  def select_all() do
    Utils.Actors.select_all()
    |> Enum.map(&as_actor_definition/1)
  end

  def select_by_pid(pid) do
    Utils.Actors.select_by_pid(pid)
    |> as_actor_definition()
  end

  def select_by_role(role_module) do
    Utils.Actors.select_by_role(role_module)
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

  defp as_actor_definition({pid, {role, serial_id, name}}) do
    %ActorDefinition{role: role, name: name, pid: pid, serial_id: serial_id}
  end
end
