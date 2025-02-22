defmodule Beamulacrum.Application do
  require Logger

  use Application

  def start(_type, _args) do
    Logger.debug("Starting Beamulacrum...")

    random_seed = Beamulacrum.Tools.random_seed()
    Logger.debug("Random seed: #{random_seed}")
    :rand.seed(:exsss, random_seed)

    run_uuid = UUID.uuid4()
    Logger.debug("Run UUID: #{run_uuid}")
    Application.put_env(:beamulacrum, :run_uuid, run_uuid)

    # Build the children list
    children =
      [
        {Beamulacrum.SupervisorRoot, []}
      ]
      |> maybe_add_action_logger()

    opts = [strategy: :one_for_one, name: Beamulacrum.Supervisor.Root]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.debug("Application started successfully!")
        actors_config = Application.fetch_env!(:beamulacrum, :actors)

        Beamulacrum.ModuleLoader.load_behaviors("./simulacrum")
        Beamulacrum.Behavior.Registry.scan_and_register_all_behaviors()

        actors_to_create =
          actors_config
          |> Enum.map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
            for _ <- 1..amt,
                do: %{
                  name: name <> " " <> to_string(Beamulacrum.Tools.increasing_int()),
                  behavior: behavior,
                  config: config
                }
          end)
          |> List.flatten()

        _pids = Beamulacrum.Connectors.Internal.create_actors(actors_to_create)
        {:ok, pid}

      {:error, reason} ->
        Logger.debug("Failed to start supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_add_action_logger(children) do
    if Application.get_env(:beamulacrum, :enable_action_logger, false) do
      Logger.debug("Starting ActionLoggerPersistent...")
      children ++ [{ActionLoggerPersistent, []}]
    else
      children
    end
  end
end
