defmodule Beamulator.ActionExecutor do
  require Logger

  @spec exec(
          {behavior :: module(), name :: binary()},
          action :: (... -> {:ok, any()} | {:error, binary()}),
          action_args :: any()
        ) :: {:ok, any()} | {:error, binary()}
  def exec({behavior, name}, action, args) when is_function(action) do
    Logger.debug("Executing action: #{inspect(action)} with args #{inspect(args)}")
    result = apply_action(action, args)

    case result do
      {:ok, _} ->
        log_event({behavior, name}, action, args, result, true)

      {:error, reason} when is_binary(reason) ->
        Logger.error("Action failed: #{reason}")
        log_event({behavior, name}, action, args, result, false)

      _ ->
        raise ArgumentError,
              "Action must return {:ok, any()} or {:error, binary()}, got: #{inspect(result)}"
    end

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

  defp log_event(ident, action, args, result, success) do
    if Application.get_env(:beamulator, :enable_action_logger, false) do
      GenServer.cast(
        Beamulator.ActionLoggerPersistent,
        {:log_event, {ident, action, args, result, success}}
      )
    end
  end
end
