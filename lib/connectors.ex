defmodule Beamulacrum.Connectors do
  require Logger

  defmodule Internal do
    def create_actor(name, behavior_module, config) do
      Beamulacrum.SupervisorActors.create_actor(name, behavior_module, config)
    end

    def create_actors(actors) do
      results =
        actors
        |> Enum.map(fn conf ->
          %{name: name, behavior: behavior, config: config} = conf

          case Beamulacrum.SupervisorActors.create_actor(
                 name,
                 behavior,
                 config
               ) do
            {:ok, pid} -> {:ok, pid}
            {:error, reason} -> {:error, reason}
          end
        end)

      {oks, errors} = results
      |> Enum.split_with(fn {:ok, _} -> true; _ -> false end)

      unless Enum.empty?(errors) do
        Logger.error("Failed to start #{length(errors)} actors.")
      end

      oks
      |> Enum.map(fn {:ok, pid} -> pid end)
    end
  end
end
