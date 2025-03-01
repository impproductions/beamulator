defmodule Beamulator.Actor.Data do
  @enforce_keys [:name, :behavior, :config, :state, :started]
  defstruct [:name, :behavior, :config, :state, :started]

  @type t :: %__MODULE__{
          name: String.t(),
          behavior: module(),
          started: boolean(),
          config: map(),
          state: map()
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

      _unexpected ->
        Logger.error("Unknown error occurred while starting actor #{name}")
        {:error, "Unknown error"}
    end
  end

  def init({name, behavior_module, config, initial_state}) do
    Logger.debug("Initializing actor: #{name}")
    selector = {behavior_module, Beamulator.Tools.increasing_int(), name}
    Registry.register(Beamulator.ActorRegistry, :actors, selector)

    state = %Data{
      name: name,
      behavior: behavior_module,
      started: false,
      config: config,
      state: initial_state
    }

    delay = :rand.uniform(100) + 50
    Process.send_after(self(), :start, delay)
    {:ok, state}
  end

  def handle_info(:start, state) do
    Logger.metadata(actor: state.name, pid: inspect(self()))
    Logger.info("Actor #{state.name} started. Scheduling first action.")
    send(self(), :act)
    {:noreply, %{state | started: true}}
  end

  def handle_info(:act, %{behavior: behavior, state: actor_state, started: started} = state) do
    Logger.metadata(actor: state.name, pid: inspect(self()))
    Logger.debug("Actor #{state.name} received action request")

    tick_number = Clock.get_tick_number()
    Logger.metadata(tick: tick_number)

    behavior_data = %Beamulator.Behavior.Data{
      name: state.name,
      config: state.config,
      state: actor_state
    }

    if started do
      Logger.info("Actor started and acting")

      {wait, new_state} =
        case behavior.act(tick_number, behavior_data) do
          {:ok, wait, new_behavior_data} ->
            Logger.debug("Actor #{state.name} acted successfully on tick #{tick_number}")
            updated_data = %{state | state: new_behavior_data.state}
            {wait, updated_data}

          {:error, wait, reason} ->
            Logger.warning("Actor #{state.name} failed to act on tick #{tick_number}: #{inspect(reason)}")
            {wait, state}
        end

      Beamulator.Dashboard.WebSocketHandler.broadcast({:actor_state_update, new_state})
      schedule_next_action(state.name, wait)
      {:noreply, new_state}
    else
      Logger.warning("Actor #{state.name} is not started yet, so it can't act. Start it with :start")
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

  defp schedule_next_action(actor_name, wait) do
    wait_ms = Tools.Time.tick_to_ms(wait)
    Logger.debug("Actor #{actor_name} scheduling next action in #{wait_ms}ms")
    Process.send_after(self(), :act, wait_ms)
  end
end
