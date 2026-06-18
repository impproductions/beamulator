defmodule Beamulator.Sinks.ActionLogger do
  @behaviour Beamulator.Sinks.Sink

  @impl true
  def log_event(%Beamulator.Sinks.Event{
        actor_id: actor_id,
        action: action,
        args: args,
        result: result,
        success: success
      }) do
    GenServer.cast(
      Beamulator.ActionLogger,
      {:log_event, {actor_id, action, args, result, success}}
    )

    :ok
  end

  @impl true
  def log_complaint(%Beamulator.Sinks.Complaint{
        actor_id: {behavior, name},
        message: message,
        severity: severity,
        action: action,
        args: args,
        meta: meta
      }) do
    GenServer.cast(
      Beamulator.ActionLogger,
      {:log_complaint, {behavior, name, message, severity, action, args, meta}}
    )

    :ok
  end
end
