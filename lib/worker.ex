defmodule Beamulacrum.Worker do
  require Logger

  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.debug("Beamulacrum has started. Press CTRL+C to stop.")
    Process.sleep(:infinity) # Keeps the process alive
    {:ok, nil}
  end
end
