defmodule Beamulator.Sinks.Sink do
  @moduledoc """
  Behaviour for modules that consume action events and complaints.
  """

  @callback log_event(Beamulator.Sinks.Event.t()) :: :ok
  @callback log_complaint(Beamulator.Sinks.Complaint.t()) :: :ok
end

defmodule Beamulator.Sinks do
  @moduledoc """
  Dispatches events and complaints to all configured sinks.
  """

  def fan_out_event(%Beamulator.Sinks.Event{} = event) do
    Enum.each(sinks(), & &1.log_event(event))
    :ok
  end

  def fan_out_complaint(%Beamulator.Sinks.Complaint{} = complaint) do
    Enum.each(sinks(), & &1.log_complaint(complaint))
    :ok
  end

  defp sinks(), do: Application.get_env(:beamulator, :action_sinks, [])
end
