defmodule Beamulator.Sinks.DashboardStats do
  @behaviour Beamulator.Sinks.Sink

  @impl true
  def log_event(%Beamulator.Sinks.Event{success: success}) do
    GenServer.cast(Beamulator.DashboardStatsProvider, {:action, success})
    :ok
  end

  @impl true
  def log_complaint(_complaint), do: :ok
end
