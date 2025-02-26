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

    Logger.debug("Starting process group...")
    {:ok, _} = :pg.start(:actor)
    Logger.info("Process group scope :actor started")

    # Define Cowboy dispatch for websockets
    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/ws", Beamulator.WebSocketHandler, []}
         ]}
      ])

    cowboy_opts = %{env: %{dispatch: dispatch}}

    children =
      [
        {Beamulator.SupervisorRoot, []},
        {Beamulator.ActorStatesProvider, []},
        %{
          id: :cowboy_listener,
          start: {:cowboy, :start_clear, [:http_listener, [{:port, 8080}], cowboy_opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 5000
        }
      ]
      |> maybe_add_action_logger()

    opts = [strategy: :one_for_one, name: Beamulator.Supervisor.Root]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.debug("Creating actors...")
        create_actors()
        Logger.info("Actors created.")

        Logger.debug("Registering behaviors...")
        Beamulator.Behavior.Registry.scan_and_register_all_behaviors()
        Logger.info("Behaviors registered.")

        Logger.debug("Starting actors...")
        start_actors(:staggered)
        Logger.info("Actors started.")
        {:ok, pid}

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

  def create_actors() do
    actors_config = Application.fetch_env!(:beamulator, :actors)

    actors_to_create =
      actors_config
      |> Enum.map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
        for _ <- 1..amt,
            do: %{
              name: name <> " " <> to_string(Beamulator.Tools.increasing_int()),
              behavior: behavior,
              config: config
            }
      end)
      |> List.flatten()

    _pids = Beamulator.Connectors.Internal.create_actors(actors_to_create)
    Logger.info("Actors initialized successfully.")
  end

  def start_actors(stagger \\ :staggered) do
    actors = Registry.lookup(Beamulator.ActorRegistry, :actors)

    chunked_actors = Enum.chunk_every(actors, 30)

    for chunk <- chunked_actors do
      for {pid, _} <- chunk do
        send(pid, :start)
      end

      if stagger == :staggered, do: Process.sleep(:rand.uniform(100) + 50)
    end
  end

  defp maybe_add_action_logger(children) do
    if Application.get_env(:beamulator, :enable_action_logger, false) do
      Logger.info("Action logger enabled, starting...")
      children = children ++ [{Beamulator.ActionLoggerPersistent, []}]
      Logger.info("Action logger started.")

      children
    else
      children
    end
  end
end
