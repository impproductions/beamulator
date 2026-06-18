defmodule Beamulator.Connectors.Internal do
  require Logger

  def create_actor(name, role_module, config) do
    Beamulator.SupervisorActors.create_actor(name, role_module, config)
  end

  def create_actors(actors) do
    results =
      actors
      |> Enum.map(fn %{name: name, role: role, config: config} ->
        case Beamulator.SupervisorActors.create_actor(name, role, config) do
          {:ok, pid} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
      end)

    {oks, errors} =
      results
      |> Enum.split_with(fn
        {:ok, _} -> true
        _ -> false
      end)

    unless Enum.empty?(errors) do
      Logger.error("Failed to start #{length(errors)} actors.")
    end

    oks
    |> Enum.map(fn {:ok, pid} -> pid end)
  end
end
