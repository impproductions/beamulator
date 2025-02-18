defmodule Beamulacrum.Behavior do
  @moduledoc """
  A behavior that all actor behaviors must implement.
  """
  @callback default_state() :: map()
  @callback decide(state :: map()) :: any()

end
