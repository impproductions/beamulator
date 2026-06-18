defmodule Beamulator.Sinks.Event do
  @enforce_keys [:actor_id, :action, :args, :result, :success, :sim_time_ms]
  defstruct [:actor_id, :action, :args, :result, :success, :sim_time_ms]

  @type t :: %__MODULE__{
          actor_id: {module(), binary()},
          action: function(),
          args: any(),
          result: {:ok, any()} | {:error, binary()},
          success: boolean(),
          sim_time_ms: integer()
        }
end

defmodule Beamulator.Sinks.Complaint do
  @enforce_keys [:actor_id, :message, :severity, :action, :args, :meta, :sim_time_ms]
  defstruct [:actor_id, :message, :severity, :action, :args, :meta, :sim_time_ms]

  @type t :: %__MODULE__{
          actor_id: {module(), binary()},
          message: binary(),
          severity: atom(),
          action: function(),
          args: any(),
          meta: map(),
          sim_time_ms: integer()
        }
end
