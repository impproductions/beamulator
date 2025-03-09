defmodule Beamulator.Tools do
  defmodule Actor do
    defmodule ActorDefinition do
      @enforce_keys [:behavior, :name, :pid, :serial_id]
      defstruct [:behavior, :name, :pid, :serial_id]

      @type t :: %__MODULE__{
              behavior: module(),
              name: String.t(),
              pid: pid(),
              serial_id: non_neg_integer()
            }
    end

    alias Beamulator.Utils

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

    defp as_actor_definition({pid, {behavior, serial_id, name}}) do
      %ActorDefinition{behavior: behavior, name: name, pid: pid, serial_id: serial_id}
    end
  end
end
