defmodule Beamulacrum.Actor.Data do
  @enforce_keys [:name, :behavior, :config, :state]
  defstruct [:name, :behavior, :config, :state]

  @type t :: %__MODULE__{
          name: String.t(),
          behavior: module(),
          config: map(),
          state: map()
        }
end

defmodule Beamulacrum.Actor do
  require Logger
  use GenServer
  alias Beamulacrum.Tools
  alias Beamulacrum.Ticker
  alias Beamulacrum.Actor.Data

  def start_link({name, behavior_module, config}) do
    Logger.debug("Attempting to start actor: #{name} with behavior #{inspect(behavior_module)}")

    initial_state = behavior_module.default_state()

    case GenServer.start_link(__MODULE__, {name, behavior_module, config, initial_state}) do
      {:ok, pid} ->
        Logger.info("Actor #{name} started successfully")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start actor #{name}: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.error("Unknown error occurred while starting actor #{name}")
        {:error, "Unknown error"}
    end
  end

  def init({name, behavior_module, config, initial_state}) do
    Logger.debug("Initializing actor: #{name}")
    selector = {behavior_module, Beamulacrum.Tools.increasing_int(), name}
    Registry.register(Beamulacrum.ActorRegistry, :actors, selector)

    Logger.debug("Actor #{name} joining group")
    Beamulacrum.ActorProcessGroup.join()

    actor_state = %Data{
      name: name,
      behavior: behavior_module,
      config: config,
      state: initial_state
    }

    Process.send_after(self(), :act, 1)

    {:ok, actor_state}
  end

  def handle_cast({:tick, tick_number}, %{behavior: behavior, state: state} = actor_data) do
    Logger.debug("Actor #{actor_data.name} received simulation tick #{tick_number}")
    Logger.metadata(tick: tick_number)

    behavior_data = %Beamulacrum.Behavior.Data{
      name: actor_data.name,
      config: actor_data.config,
      state: state
    }

    case behavior.act(tick_number, behavior_data) do
      {:ok, new_behavior_data} ->
        Logger.debug("Actor #{actor_data.name} acted successfully on tick #{tick_number}")
        new_state = %{actor_data | state: new_behavior_data.state}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.warning(
          "Actor #{actor_data.name} failed to act on tick #{tick_number}: #{inspect(reason)}"
        )

        {:noreply, actor_data}
    end
  end

  def handle_info(:act, %{behavior: behavior, state: state} = actor_data) do
    Logger.debug("Actor #{actor_data.name} received action request")
    tick_number = Ticker.get_tick_number()
    Logger.metadata(tick: tick_number)

    behavior_data = %Beamulacrum.Behavior.Data{
      name: actor_data.name,
      config: actor_data.config,
      state: state
    }

    {wait, new_actor_data} = case behavior.act(tick_number, behavior_data) do
      {:ok, wait, new_behavior_data} ->
        Logger.debug("Actor #{actor_data.name} acted successfully on tick #{tick_number}")
        new_actor_data = %{actor_data | state: new_behavior_data.state}
        {wait, new_actor_data}

      {:error, wait, reason} ->
        Logger.warning(
          "Actor #{actor_data.name} failed to act on tick #{tick_number}: #{inspect(reason)}"
        )

        {wait, actor_data}
    end

    wait_in_ms = wait * Tools.Time.tick_interval_ms()

    Logger.debug("Actor #{actor_data.name} scheduling next action in #{wait_in_ms}ms")

    Process.send_after(self(), :act, wait_in_ms)

    {:noreply, new_actor_data}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end
end
