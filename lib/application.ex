defmodule Beamulator.Application do
  require Logger
  use Application

  def start(_type, _args) do
    Logger.info("Starting Beamulator...")

    maybe_override_questdb_from_env()

    run_uuid = UUID.uuid4()
    Logger.debug("Run UUID: #{run_uuid}")
    Application.put_env(:beamulator, :run_uuid, run_uuid)

    random_seed = Beamulator.Utils.random_seed()
    Logger.debug("Setting random seed: #{random_seed}")
    :rand.seed(:exsss, random_seed)
    Logger.info("Random seed set to: #{random_seed}")

    Logger.debug("Loading actors configuration...")
    Application.put_env(:beamulator, :actors, Beamulator.ActorsConfig.actors())
    Logger.info("Actors configuration loaded. #{inspect(Application.fetch_env!(:beamulator, :actors))}")

    children =
      [
        {Registry, keys: :duplicate, name: Beamulator.WebsocketRegistry},
        {Beamulator.SupervisorSimulation, []},
        {Beamulator.HttpRouter, []},
        {Beamulator.DashboardStatsProvider, []},
      ]
      |> maybe_add_action_logger()
      |> maybe_add_memory_sink()

    opts = [strategy: :one_for_one, name: Beamulator.Supervisor.Root]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      simulation_config = Application.fetch_env!(:beamulator, :simulation)
      Logger.info("Simulation configuration: #{inspect(simulation_config)}")

      if simulation_config[:begin_on_start] do
        Logger.debug("Creating actors...")
        Beamulator.start_actors()
        Logger.info("Actors created.")
      end

      {:ok, pid}
    else
      {:error, reason} ->
        Logger.error("Failed to start supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # def create_actors do
  #   actors_config = Application.fetch_env!(:beamulator, :actors)

  #   actors_config
  #   |> Enum.flat_map(fn %{name: name, behavior: behavior, config: config, amt: amt} ->
  #     for _ <- 1..amt do
  #       %{
  #         name: "#{name} #{Beamulator.Utils.increasing_int()}",
  #         behavior: behavior,
  #         config: config
  #       }
  #     end
  #   end)
  #   |> Enum.each(fn %{name: name, behavior: behavior, config: config} ->
  #     Beamulator.Connectors.Internal.create_actor(name, behavior, config)
  #     Process.sleep(:rand.uniform(100) + 50)
  #   end)

  #   Logger.info("Actors initialized successfully.")
  # end

  defp maybe_add_action_logger(children) do
    if Application.get_env(:beamulator, :enable_action_logger, false) do
      Logger.info("Action logger enabled, starting...")
      children ++ [{Beamulator.ActionLogger, []}]
    else
      children
    end
  end

  defp maybe_override_questdb_from_env() do
    case {System.get_env("BEAMULATOR_QUESTDB_URL"), System.get_env("BEAMULATOR_QUESTDB_PORT")} do
      {nil, nil} ->
        :ok

      {url, port_str} ->
        base = Application.get_env(:beamulator, :questdb, %{})
        port = if port_str, do: String.to_integer(port_str), else: base[:port] || 9000
        url = url || base[:url] || "http://localhost"
        Application.put_env(:beamulator, :questdb, Map.merge(base, %{url: url, port: port}))
    end
  end

  defp maybe_add_memory_sink(children) do
    if Application.get_env(:beamulator, :start_memory_sink, false) do
      Logger.info("Memory sink enabled, starting...")
      children ++ [{Beamulator.Sinks.Memory, []}]
    else
      children
    end
  end
end
