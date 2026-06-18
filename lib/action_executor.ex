defmodule Beamulator.ActionExecutor do
  require Logger
  alias Beamulator.Sinks
  alias Beamulator.Sinks.Event

  @spec exec(
          {behavior :: module(), name :: binary()},
          action :: (... -> {:ok, any()} | {:error, binary()}),
          action_args :: any()
        ) :: {:ok, any()} | {:error, binary()}
  def exec({behavior, name}, action, args) when is_function(action) do
    Logger.debug("Executing action: #{inspect(action)} with args #{inspect(args)}")
    result = apply_action(action, args)

    success =
      case result do
        {:ok, _} ->
          true

        {:error, reason} when is_binary(reason) ->
          Logger.error("Action failed: #{reason}")
          false

        _ ->
          raise ArgumentError,
                "Action must return {:ok, any()} or {:error, binary()}, got: #{inspect(result)}"
      end

    Sinks.fan_out_event(%Event{
      actor_id: {behavior, name},
      action: action,
      args: args,
      result: result,
      success: success,
      sim_time_ms: Beamulator.Clock.get_simulation_now()
    })

    Logger.debug("Action #{inspect(action)} finished executing with result #{inspect(result)}")
    result
  end

  @spec exec(
          {behavior :: module(), name :: binary()},
          action :: (... -> {:ok, any()} | {:error, binary()})
        ) :: {:ok, any()} | {:error, binary()}
  def exec({behavior, name}, action) do
    exec({behavior, name}, action, nil)
  end

  defp apply_action(action, args) do
    apply(action, List.wrap(args))
  end
end
