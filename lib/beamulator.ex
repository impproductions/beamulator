defmodule Beamulator do
  @moduledoc """
  Top-level entry points for controlling a running simulation.
  """

  defdelegate start_actors(), to: Beamulator.ActorInizializer, as: :start_creation
end
