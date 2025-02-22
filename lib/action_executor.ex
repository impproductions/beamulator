defmodule Beamulacrum.ActionExecutor do
  @moduledoc """
  Executes user-defined actions from the Beamulacrum.Actions module.
  """

  require Logger

  def exec({behavior, name}, action, args) when is_function(action) do
    IO.puts("Executing action: #{inspect(action)} with args #{inspect(args)}")

    result = apply_action(action, args)

    unless match?({:ok, _}, result) or match?({:error, _} when is_binary(elem(result, 1)), result) do
      raise ArgumentError,
            "Action must return {:ok, any()} or {:error, String.t()}, got: #{inspect(result)}"
    end

    logger_enabled = Application.get_env(:beamulacrum, :start_action_logger, false)

    case result do
      {:error, reason} ->
        Logger.error("Action failed: #{reason}")

      _ ->
        if logger_enabled,
          do: GenServer.cast(ActionLoggerPersistent, {:log_event, {{behavior, name}, action, args, result}})
    end

    IO.puts("Action result: #{inspect(result)}")

    result
  end

  def exec({behavior, name}, action) do
    exec({behavior, name}, action, nil)
  end

  defp apply_action(action, args) do
    apply(action, List.wrap(args))
  end
end
