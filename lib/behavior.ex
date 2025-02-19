defmodule Beamulacrum.Behavior.Data do
  @enforce_keys [:name, :state]
  defstruct [:name, :state]

  @type t :: %__MODULE__{
          name: String.t(),
          state: map()
        }
end

defmodule Beamulacrum.Behavior do
  @moduledoc """
  A behavior that all actor behaviors must implement.
  """
  alias Beamulacrum.Behavior

  @callback default_state() :: map()
  @callback act(tick :: integer(), state :: Behavior.Data.t()) :: {:ok, Behavior.Data.t()} | {:error, String.t()}
end
