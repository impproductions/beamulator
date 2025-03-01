defmodule Beamulator.Application do
  require Logger
  use Application

  def start(_type, _args) do
    Logger.info("Starting Beamulator...")

    run_uuid = UUID.uuid4()
    Logger.debug("Run UUID: #{run_uuid}")
    Application.put_env(:beamulator, :run_uuid, run_uuid)

    random_seed = Beamulator.Tools.random_seed()
    Logger.debug("Setting random seed: #{random_seed}")
    :rand.seed(:exsss, random_seed)
    Logger.info("Random seed set to: #{random_seed}")

    children =
      [
        {Registry, keys: :duplicate, name: Beamulator.WebsocketRegistry},
        {Beamulator.SupervisorSimulation, []},
        # {Beamulator.SupervisorWebsocket, []}
      ]
      |> maybe_add_action_logger()

    opts = [strategy: :one_for_one, name: Beamulator.Supervisor.Root]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      simulation_config = Application.fetch_env!(:beamulator, :simulation)
      Logger.info("Simulation configuration: #{inspect(simulation_config)}")

      if simulation_config[:begin_on_start] do
        Logger.debug("Creating actors (staggered)...")
        create_actors()
        Logger.info("Actors created.")
      end

      Logger.debug("Registering behaviors...")
      Beamulator.Behavior.Registry.scan_and_register_all_behaviors()
      Logger.info("Behaviors registered.")

      {:ok, pid}
    else
      {:error, reason} ->
        Logger.error("Failed to start supervisor: #{inspect(reason)}")
        {:error, reason}
    end

    case Beamulator.Dashboard.StaticServer.start_link([]) do
      {:ok, _} ->
        Logger.info("Dashboard started.")

      {:error, reason} ->
        Logger.error("Failed to start dashboard: #{inspect(reason)}")
    end

    {:ok, self()}
  end

  def create_actors do
    actors_config = Application.fetch_env!(:beamulator, :actors)

    actors_config
    |> Enum.flat_map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
      for _ <- 1..amt do
        %{
          # Changed concatenation from name <> " " <> to_string(...) to interpolation.
          name: "#{name} #{Beamulator.Tools.increasing_int()}",
          behavior: behavior,
          config: config
        }
      end
    end)
    |> Enum.each(fn %{name: name, behavior: behavior, config: config} ->
      Beamulator.Connectors.Internal.create_actor(name, behavior, config)
      Process.sleep(:rand.uniform(100) + 50)
    end)

    Logger.info("Actors initialized successfully.")
  end

  defp maybe_add_action_logger(children) do
    if Application.get_env(:beamulator, :enable_action_logger, false) do
      Logger.info("Action logger enabled, starting...")
      children ++ [{Beamulator.ActionLoggerPersistent, []}]
    else
      children
    end
  end
end
