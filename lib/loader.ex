defmodule Beamulacrum.ModuleLoader do
  @moduledoc """
  Loads user-defined modules dynamically from a given path.
  Ensures that only modules implementing `Beamulacrum.Behavior` are kept.
  Also loads the `Actions` module once.
  """

  @actions_path "./simulacrum/actions.ex"

  def load_user_modules(path) do
    load_actions_module()

    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".ex"))
        |> Enum.filter(fn f -> f != "actions.ex" end)
        |> Enum.map(&Path.join(path, &1))
        |> Enum.each(&compile_and_load_module/1)

      {:error, reason} ->
        IO.puts("Failed to list directory #{path}: #{inspect(reason)}")
    end
  end

  defp compile_and_load_module(file) do
    modules_before = get_loaded_modules()

    try do
      IO.puts("Loading file #{file}")
      Code.compile_file(file)
      modules_after = get_loaded_modules()
      new_modules = modules_after -- modules_before

      Enum.each(new_modules, fn module ->
        if implements_behavior?(module, Beamulacrum.Behavior) do
          IO.puts("Loaded behavior module: #{inspect(module)}")
        else
          IO.puts("Skipping non-behavior module: #{inspect(module)}")
          purge_module(module)
        end
      end)
    rescue
      exception ->
        IO.puts("Error loading #{file}: #{Exception.message(exception)}")
    end
  end

  defp load_actions_module do
    unless :persistent_term.get(:beamulacrum_actions_module, nil) do
      case Code.compile_file(@actions_path) do
        [{mod, _}] ->
          :persistent_term.put(:beamulacrum_actions_module, mod)
          IO.puts("Loaded Actions module: #{inspect(mod)}")
          mod

        _ ->
          IO.puts("Failed to load Actions module")
          nil
      end
    end
  end

  defp implements_behavior?(module, behavior) do
    required_callbacks = behavior.behaviour_info(:callbacks) |> Enum.map(&elem(&1, 0))

    Enum.all?(required_callbacks, fn callback ->
      function_exported?(module, callback, 1) or function_exported?(module, callback, 0)
    end)
  end

  defp get_loaded_modules do
    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
  end

  defp purge_module(module) do
    :code.purge(module)
    :code.delete(module)
  end
end
