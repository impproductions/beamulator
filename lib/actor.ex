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
  alias Beamulacrum.Actor.Data

  def start_link({name, behavior_module, config}) do
    Logger.debug("Attempting to start actor: #{name} with behavior #{inspect(behavior_module)}")

    initial_state = behavior_module.default_state()

    case GenServer.start_link(__MODULE__, {name, behavior_module, config, initial_state}) do
      {:ok, pid} ->
        Logger.debug("Actor #{name} started successfully with PID #{inspect(pid)}")
        {:ok, pid}

      {:error, reason} ->
        Logger.debug("Failed to start actor #{name}: #{inspect(reason)}")
        {:error, reason}

      _ ->
        Logger.debug("Unknown error")
        {:error, "Unknown error"}
    end


  end

  def init({name, behavior_module, config, initial_state}) do
    Logger.debug("Initializing actor: #{name}")
    selector = {behavior_module, Beamulacrum.Tools.increasing_int(), name}
    Registry.register(Beamulacrum.ActorRegistry, :actors, selector)

    actor_state = %Data{
      name: name,
      behavior: behavior_module,
      config: config,
      state: initial_state
    }

    {:ok, actor_state}
  end

  def handle_cast({:tick, tick_number}, %{behavior: behavior, state: state} = actor_data) do
    Logger.debug("Actor #{actor_data.name} reacting to simulation tick #{tick_number}")
    Logger.metadata(tick: tick_number)

    behavior_data = %Beamulacrum.Behavior.Data{
      name: actor_data.name,
      config: actor_data.config,
      state: state
    }

    case behavior.act(tick_number, behavior_data) do
      {:ok, new_behavior_data} ->
        Logger.debug("Actor #{actor_data.name} acted successfully")
        new_state = %{actor_data | state: new_behavior_data.state}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.debug("Actor #{actor_data.name} failed to act: #{reason}")
        {:noreply, actor_data}
    end

  end

  # def handle_info({:tick, tick_number}, %{behavior: behavior, state: state} = actor_data) do
  #   Logger.debug("Actor #{actor_data.name} reacting to simulation tick #{tick_number}")
  #   Logger.metadata(tick: tick_number)

  #   behavior_data = %Beamulacrum.Behavior.Data{
  #     name: actor_data.name,
  #     config: actor_data.config,
  #     state: state
  #   }

  #   case behavior.act(tick_number, behavior_data) do
  #     {:ok, new_behavior_data} ->
  #       Logger.debug("Actor #{actor_data.name} acted successfully")
  #       new_state = %{actor_data | state: new_behavior_data.state}
  #       {:noreply, new_state}

  #     {:error, reason} ->
  #       Logger.debug("Actor #{actor_data.name} failed to act: #{reason}")
  #       {:noreply, actor_data}
  #   end
  # end

end
