defmodule Beamulator.Behavior.ActPayload do
  @enforce_keys [:actor_serial_id, :actor_name, :actor_config, :actor_state]
  defstruct [:actor_serial_id, :actor_name, :actor_config, :actor_state]

  @type t :: %__MODULE__{
          actor_serial_id: integer(),
          actor_name: binary(),
          actor_config: map(),
          actor_state: map()
        }
end

defmodule Beamulator.Behavior.Complaint do
  @enforce_keys [:trigger, :message, :severity, :code]
  defstruct [:trigger, :message, :severity, :code]

  @type t :: %__MODULE__{
          trigger: fun(),
          message: binary(),
          severity: :urgent | :annoying | :justsayin,
          code: binary()
        }
end

defmodule Beamulator.Behavior.ComplaintBuilder do
  defmacro build_complaint(trigger, message, severity) do
    code = Macro.to_string(trigger)

    quote do
      %Beamulator.Behavior.Complaint{
        trigger: unquote(trigger),
        message: unquote(message),
        severity: unquote(severity),
        code: unquote(code)
      }
    end
  end
end

defmodule Beamulator.Behavior do
  @doc """
  The default_state function should return the initial state of the behavior.
  """
  @callback default_state() :: map()

  @doc """
  The act function is called by the ActionExecutor to execute an action.
  It returns a tuple with:
    - the result of the action, either `:ok` or `:error`
    - the time to wait before the next action, in ms, in simulation time (e.s. 1 second is 100ms in simulation time if the simulation is running at 10x speed)
    - the updated behavior data
  """
  @callback act(simulation_time_ms :: integer(), actor_data :: Beamulator.Behavior.ActPayload.t()) ::
              {:ok, wait_ms :: integer(), new_data :: Beamulator.Behavior.ActPayload.t()}
              | {:error, wait_ms :: integer(), new_data :: Beamulator.Behavior.ActPayload.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Beamulator.Behavior

      require Logger
      alias Beamulator.ActionExecutor

      def execute(actor_data, action) do
        execute(actor_data, action, nil)
      end

      def execute(actor_data, action, args) do
        Logger.debug("#{actor_data.actor_name} executing action #{inspect(action)} with args #{inspect(args)}")
        result = ActionExecutor.exec({__MODULE__, actor_data.actor_name}, action, args)
        Logger.info("#{actor_data.actor_name} executed action #{inspect(action)} with args #{inspect(args)}")
        result
      end

      def execute(actor_data, action, args, complaint) when is_struct(complaint) do
        execute(actor_data, action, args, [complaint])
      end

      def execute(actor_data, action, args, complaints) when is_list(complaints) do
        {status, result} = execute(actor_data, action, args)

        complaints
        |> Enum.each(fn complaint ->
          condition = complaint.trigger.({status, result})

          if condition do
            Logger.error(
              "Complaint triggered: #{complaint.message}. trigger code: #{complaint.code}"
            )

            GenServer.cast(Beamulator.ActionLogger, {
              :log_complaint,
              {
                __MODULE__,
                actor_data.actor_name,
                complaint.message,
                complaint.severity,
                action,
                args,
                %{
                  trigger: complaint.code,
                  status: status,
                  result: result
                }
              }
            })
          end
        end)

        {status, result}
      end
    end
  end
end
