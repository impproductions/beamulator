defmodule Beamulator.ModuleLoader do
  require Logger

  def load_behaviors(path) do
    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".ex"))
        |> Enum.filter(fn f -> f != "actions.ex" end)
        |> Enum.map(&Path.join(path, &1))
        |> Enum.each(&compile_and_load_module/1)

        nil

      {:error, reason} ->
        Logger.warning("Failed to list directory #{path}: #{inspect(reason)}")
    end
  end

  defp compile_and_load_module(file) do
    modules_before = get_loaded_modules()

    try do
      Logger.debug("Loading file #{file}")
      Code.compile_file(file)
      modules_after = get_loaded_modules()
      new_modules = modules_after -- modules_before

      Enum.each(new_modules, fn module ->
        if implements_behavior?(module) do
          Logger.info("Loaded behavior module: #{inspect(module)}")
        else
          Logger.debug("Skipping non-behavior module: #{inspect(module)}")
        end
      end)
    rescue
      exception ->
        Logger.error("Error loading #{file}: #{Exception.message(exception)}")
    end
  end

  def implements_behavior?(module) do
    module
    |> Atom.to_string()
    |> String.starts_with?("Elixir.Beamulator.Behaviors.")
  end

  defp get_loaded_modules do
    found_modules_count = :code.all_loaded()
    |> Enum.count()

    Logger.debug("Loaded modules count: #{found_modules_count}")

    :code.all_loaded()
    |> Enum.map(&elem(&1, 0))
  end
end
