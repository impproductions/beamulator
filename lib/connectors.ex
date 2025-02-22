defmodule Beamulacrum.Connectors do
  require Logger

  defmodule Internal do
    def create_actor(name, behavior_module, config) do
      Beamulacrum.SupervisorActors.start_actor(name, behavior_module, config)
    end

    def create_actors(actors) do
      results =
        actors
        |> Enum.map(fn conf ->
          %{name: name, behavior: behavior, config: config} = conf

          case Beamulacrum.SupervisorActors.start_actor(
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

      errors
      |> Enum.each(fn {:error, reason} ->
        Logger.debug("Error starting actor: #{inspect(reason)}")
      end)

      oks
      |> Enum.map(fn {:ok, pid} -> pid end)
    end
  end
end
