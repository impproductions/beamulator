defmodule Beamulacrum.Behavior.Data do
  @enforce_keys [:name, :config, :state]
  defstruct [:name, :config, :state]


  @type t :: %__MODULE__{
          name: String.t(),
          config: map(),
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
