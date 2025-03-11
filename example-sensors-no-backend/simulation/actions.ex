defmodule Beamulator.Actions do
  use SourceInjector
  require Logger

  def send_collected_metrics(sensors) do
    Logger.info("Sending collected metrics: #{inspect(sensors)}")
    {:ok, %{}}
  end

end
