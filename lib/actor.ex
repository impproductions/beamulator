defmodule Beamulator.Actor.Data do
  @enforce_keys [:name, :behavior, :config, :state, :started, :action_count, :last_action_time]
  defstruct [:name, :behavior, :config, :state, :started, :action_count, :last_action_time]

  @type t :: %__MODULE__{
          name: String.t(),
          behavior: module(),
          started: boolean(),
          config: map(),
          state: map(),
          action_count: non_neg_integer(),
          last_action_time: non_neg_integer()
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
    selector = {behavior_module, Beamulator.Tools.increasing_int(), name}
    Registry.register(Beamulator.ActorRegistry, :actors, selector)

    state = %Data{
      name: name,
      behavior: behavior_module,
      action_count: 0,
      last_action_time: Clock.get_simulation_duration_ms(),
      started: false,
      config: config,
      state: initial_state
    }

    delay = :rand.uniform(100) + 50
    Process.send_after(self(), :start, delay)

    Beamulator.Dashboard.WebSocketHandler.broadcast(:send_behaviors)

    {:ok, state}
  end

  def handle_info(:start, state) do
    Logger.metadata(actor: state.name, pid: inspect(self()))
    Logger.info("Actor #{state.name} started. Scheduling first action.")
    send(self(), :act)
    {:noreply, %{state | started: true}}
  end

  def handle_info(:act, %{behavior: behavior, state: actor_state, started: started} = state) do
    simulation_time_ms = Clock.get_simulation_duration_ms()

    Logger.metadata(
      actor: state.name,
      pid: inspect(self()),
      simulation_time_ms: simulation_time_ms
    )

    Logger.debug("Actor #{state.name} received action request")

    behavior_data = %Beamulator.Behavior.Data{
      name: state.name,
      config: state.config,
      state: actor_state
    }

    if started do
      {wait_simulation_time_ms, new_state} =
        case behavior.act(simulation_time_ms, behavior_data) do
          {:ok, wait_simulation_time_ms, new_behavior_data} ->
            Logger.debug("Actor #{state.name} acted successfully at #{simulation_time_ms}")
            updated_state = %{state | state: new_behavior_data.state}
            {wait_simulation_time_ms, updated_state}

          {:error, wait_simulation_time_ms, reason} ->
            Logger.error(
              "Actor #{state.name} failed to act on at #{simulation_time_ms}: #{inspect(reason)}"
            )

            {wait_simulation_time_ms, state}
        end

      new_state = %{
        new_state
        | action_count: new_state.action_count + 1,
          last_action_time: simulation_time_ms
      }

      Beamulator.Dashboard.WebSocketHandler.broadcast({:actor_state_update, new_state})
      schedule_next_action(state.name, wait_simulation_time_ms)

      {:noreply, new_state}
    else
      Logger.warning(
        "Actor #{state.name} is not started yet, so it can't act. Start it with :start"
      )

      {:noreply, state}
    end
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def terminate(reason, state) do
    Logger.error("Actor #{state.name} terminating with reason: #{inspect(reason)}")
    :ok
  end

  defp schedule_next_action(actor_name, wait_simulation_time_ms) do
    wait_real_time_ms = div(wait_simulation_time_ms, Tools.Time.time_speed_multiplier())

    Logger.debug(
      "Actor #{actor_name} scheduling next action in #{Tools.Duration.to_string(wait_simulation_time_ms)} simulation time (#{Tools.Duration.to_string(wait_real_time_ms)})"
    )

    Process.send_after(self(), :act, wait_real_time_ms)
  end
end
