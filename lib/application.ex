defmodule Beamulacrum.Application do
  require Logger

  use Application

  def start(_type, _args) do
    Logger.info("Starting Beamulacrum...")

    run_uuid = UUID.uuid4()
    Logger.debug("Run UUID: #{run_uuid}")
    Application.put_env(:beamulacrum, :run_uuid, run_uuid)

    random_seed = Beamulacrum.Tools.random_seed()
    Logger.debug("Setting random seed: #{random_seed}")
    :rand.seed(:exsss, random_seed)
    Logger.info("Random seed set to: #{random_seed}")

    Logger.debug("Starting process group...")
    {:ok, _} = :pg.start(:actor)
    Logger.info("Process group scope :actor started")

    children =
      [
        {Beamulacrum.SupervisorRoot, []}
      ]
      |> maybe_add_action_logger()

    opts = [strategy: :one_for_one, name: Beamulacrum.Supervisor.Root]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.debug("Creating actors...")
        create_actors()
        Logger.info("Actors created.")

        Logger.debug("Registering behaviors...")
        Beamulacrum.Behavior.Registry.scan_and_register_all_behaviors()
        Logger.info("Behaviors registered.")

        Logger.debug("Starting actors...")
        start_actors(:staggered)
        Logger.info("Actors started.")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def create_actors() do
    actors_config = Application.fetch_env!(:beamulacrum, :actors)

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
    Logger.info("Actors initialized successfully.")
  end

  def start_actors(stagger \\ :staggered) do
    actors = Registry.lookup(Beamulacrum.ActorRegistry, :actors)

    for {pid, _} <- actors do
      send(pid, :start)
      if stagger == :staggered, do: Process.sleep(:rand.uniform(10))
    end
  end

  defp maybe_add_action_logger(children) do
    if Application.get_env(:beamulacrum, :enable_action_logger, false) do
      Logger.info("Action logger enabled, starting...")
      children = children ++ [{ActionLoggerPersistent, []}]
      Logger.info("Action logger started.")

      children
    else
      children
    end
  end
end
