defmodule Beamulator.ActionExecutor do
  require Logger

  def exec({behavior, name}, action, args) when is_function(action) do
    Logger.debug("Executing action: #{inspect(action)} with args #{inspect(args)}")

    result = apply_action(action, args)

    unless match?({:ok, _}, result) or match?({:error, _} when is_binary(elem(result, 1)), result) do
      raise ArgumentError,
            "Action must return {:ok, any()} or {:error, String.t()}, got: #{inspect(result)}"
    end

    logger_enabled = Application.get_env(:beamulator, :enable_action_logger, false)

    case result do
      {:error, reason} ->
        Logger.error("Action failed: #{reason}")

      _ ->
        if logger_enabled,
          do: GenServer.cast(Beamulator.ActionLoggerPersistent, {:log_event, {{behavior, name}, action, args, result}})
    end

    Logger.debug("Action #{inspect(action)} finished executing with result #{inspect(result)}")

    result
  end

  def exec({behavior, name}, action) do
    exec({behavior, name}, action, nil)
  end

  defp apply_action(action, args) do
    apply(action, List.wrap(args))
  end
end
