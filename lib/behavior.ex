defmodule Beamulacrum.Behavior.State do
  @enforce_keys [:name, :data]
  defstruct [:name, :data]

  @type t :: %__MODULE__{
          name: String.t(),
          data: map()
        }
end

defmodule Beamulacrum.Behavior do
  @moduledoc """
  A behavior that all actor behaviors must implement.
  """
  alias Beamulacrum.Behavior.State

  @callback default_state() :: map()
  @callback act(tick :: integer(), state :: State.t()) :: {:ok, State.t()} | {:error, String.t()}
end
