defmodule Beamulator.Actor.Data do
  @enforce_keys [:serial_id, :name, :behavior, :config, :state, :runtime_stats]
  defstruct [
    :serial_id,
    :name,
    :behavior,
    :config,
    :state,
    runtime_stats: %{
      started: false,
      action_count: 0,
      last_action_time: 0
    }
  ]

  @type t :: %__MODULE__{
          serial_id: non_neg_integer(),
          name: String.t(),
          behavior: module(),
          config: map(),
          state: map(),
          runtime_stats: %{
            started: boolean(),
            action_count: non_neg_integer(),
            last_action_time: non_neg_integer()
          }
        }
end

defmodule Beamulator.Simulation.SimulationData do
  @enforce_keys [:now_ms, :duration_ms, :start_time_ms]
  defstruct [:now_ms, :duration_ms, :start_time_ms]

  @type t :: %__MODULE__{
          now_ms: non_neg_integer(),
          duration_ms: non_neg_integer(),
          start_time_ms: non_neg_integer()
        }
end

defmodule Beamulator.Actor do
  require Logger
  use GenServer

  alias Beamulator.Tools
  alias Beamulator.Clock
  alias Beamulator.Actor.Data

  def start_link({name, behavior_module, config}) do
    Logger.debug("Attempting to start actor: #{name} with behavior #{inspect(behavior_module)}")

    initial_state = behavior_module.default_state()

    case GenServer.start_link(__MODULE__, {name, behavior_module, config, initial_state}) do
      {:ok, pid} ->
        Logger.debug("Actor #{name} started successfully")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start actor #{name}: #{inspect(reason)}")
        {:error, reason}

      unexpected ->
        Logger.error(
          "Unknown error occurred while starting actor #{name}: #{inspect(unexpected)}"
        )

        {:error, "Unknown error: #{inspect(unexpected)}"}
    end
  end

  def init({name, behavior_module, config, initial_state}) do
    Logger.debug("Initializing actor: #{name}")
    serial_id = Beamulator.Tools.increasing_int()
    selector = {behavior_module, serial_id, name}
    Registry.register(Beamulator.ActorRegistry, :actors, selector)

    state = %Data{
      serial_id: serial_id,
      name: name,
      behavior: behavior_module,
      config: config,
      state: initial_state,
      runtime_stats: %{
        schedule_position: 0,
        action_count: 0,
        last_action_time: Clock.get_simulation_duration_ms(),
        started: false
      }
    }

    delay = :rand.uniform(10) + 5
    Process.send_after(self(), :start, delay)

    Beamulator.Dashboard.WebSocketHandler.broadcast(:send_behaviors)

    {:ok, state}
  end

  def handle_info(:start, state) do
    Logger.metadata(actor: state.name, pid: inspect(self()))
    Logger.info("Actor #{state.name} started. Scheduling first action.")
    send(self(), :act)
    {:noreply, %{state | runtime_stats: %{state.runtime_stats | started: true}}}
  end

  def handle_info(
        :act,
        %{behavior: behavior, state: actor_state, runtime_stats: %{started: started}} = state
      ) do
    action_start_time = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    simulation_time_ms = Clock.get_simulation_now()

    Logger.metadata(
      actor: state.name,
      pid: inspect(self()),
      simulation_time_ms: simulation_time_ms
    )

    Logger.debug("Actor #{state.name} received action request")

    behavior_data = %Beamulator.Behavior.ActPayload{
      simulation_data: %Beamulator.Simulation.SimulationData{
        now_ms: simulation_time_ms,
        duration_ms: Clock.get_simulation_duration_ms(),
        start_time_ms: Clock.get_start_time()
      },
      actor_serial_id: state.serial_id,
      actor_name: state.name,
      actor_config: state.config,
      actor_state: actor_state,
      actor_runtime: state.runtime_stats
    }

    if started do
      {wait_simulation_time_ms, new_state} =
        case behavior.act(behavior_data) do
          {:ok, wait_simulation_time_ms, new_behavior_data} ->
            Logger.debug("Actor #{state.name} acted successfully at #{simulation_time_ms}")
            updated_state = %{state | state: new_behavior_data.actor_state}
            {wait_simulation_time_ms, updated_state}

          {:error, wait_simulation_time_ms, reason} ->
            Logger.error(
              "Actor #{state.name} failed to act on at #{simulation_time_ms}: #{inspect(reason)}"
            )

            {wait_simulation_time_ms, state}
        end

      new_state = %{
        new_state
        | runtime_stats: %{
            new_state.runtime_stats
            | action_count: new_state.runtime_stats.action_count + 1,
              last_action_time: simulation_time_ms
          }
      }

      Beamulator.Dashboard.WebSocketHandler.broadcast({:actor_state_update, new_state})

      schedule_next_action(state, wait_simulation_time_ms, action_start_time)

      {:noreply, new_state}
    else
      Logger.warning(
        "Actor #{state.name} is not started yet, so it can't act. Start it with :start"
      )

      {:noreply, state}
    end
  end

  def handle_cast({:update_state, key, value}, state) do
    new_state = %{state | state: Map.put(state.state, key, value)}
    {:noreply, new_state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def terminate(reason, state) do
    Logger.error("Actor #{state.name} terminating with reason: #{inspect(reason)}")

    GenServer.cast(Beamulator.DashboardStatsProvider, {:actor, :crash})
    :ok
  end

  defp schedule_next_action(state, wait_simulation_time_ms, action_start_time) do
    actor_name = state.name
    wait_real_time_ms = div(wait_simulation_time_ms, Tools.Time.time_speed_multiplier())

    elapsed = (DateTime.utc_now() |> DateTime.to_unix(:millisecond)) - action_start_time

    Logger.debug(
      "Actor #{actor_name} scheduling next action in #{Tools.Duration.to_string(wait_simulation_time_ms)} simulation time (#{Tools.Duration.to_string(wait_real_time_ms)})"
    )

    drift_adjusted = wait_real_time_ms - elapsed
    Process.send_after(self(), :act, drift_adjusted)
  end
end
