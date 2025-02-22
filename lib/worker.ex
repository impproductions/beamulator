defmodule Beamulacrum.Worker do
  require Logger

  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("Beamulacrum has started.")
    Process.sleep(:infinity) # Keeps the process alive
    {:ok, nil}
  end
end
