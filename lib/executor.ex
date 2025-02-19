defmodule Beamulacrum.ActionExecutor do
  @moduledoc """
  Executes user-defined actions from the Beamulacrum.Actions module.
  """

  @spec exec((... -> {:ok, any()} | {:error, String.t()}), any()) ::
          {:ok, any()} | {:error, String.t()}
  def exec(action, args) when is_function(action) do
    IO.puts("Executing action: #{inspect(action)} with args #{inspect(args)}")

    result = apply_action(action, args)

    unless match?({:ok, _}, result) or match?({:error, _} when is_binary(elem(result, 1)), result) do
      raise ArgumentError,
            "Action must return {:ok, any()} or {:error, String.t()}, got: #{inspect(result)}"
    end

    IO.puts("Action result: #{inspect(result)}")

    result
  end

  @spec exec((... -> {:error, String.t()} | {:ok, any()})) :: {:error, String.t()} | {:ok, any()}
  def exec(action) do
    exec(action, nil)
  end

  defp apply_action(action, args) do
    apply(action, List.wrap(args))
  end
end
