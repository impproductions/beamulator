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
  alias Beamulacrum.Actor.Data
  use GenServer

  def start_link({name, behavior_module, config}) do
    IO.puts("Attempting to start actor: #{name} with behavior #{inspect(behavior_module)}")

    initial_state = behavior_module.default_state()

    case GenServer.start_link(__MODULE__, {name, behavior_module, config, initial_state},
           name: via_tuple(name)
         ) do
      {:ok, pid} ->
        IO.puts("Actor #{name} started successfully with PID #{inspect(pid)}")
        {:ok, pid}

      {:error, reason} ->
        IO.puts("Failed to start actor #{name}: #{inspect(reason)}")
        {:error, reason}

      _ ->
        IO.puts("Unknown error")
        {:error, "Unknown error"}
    end
  end

  def init({name, behavior_module, config, initial_state}) do
    IO.puts("Initializing actor: #{name}")

    actor_state = %Data{
      name: name,
      behavior: behavior_module,
      config: config,
      state: initial_state
    }

    case Registry.register(Beamulacrum.ActorRegistry, :actors, self()) do
      {:ok, _} ->
        IO.puts("Actor #{name} registered successfully in ActorRegistry")

      {:error, reason} ->
        IO.puts("Failed to register actor #{name}: #{inspect(reason)}")
    end

    {:ok, actor_state}
  end

  def handle_info({:tick, tick_number}, %{behavior: behavior, state: state} = actor_data) do
    IO.puts("Actor #{actor_data.name} reacting to simulation tick #{tick_number}")

    behavior_state = %Beamulacrum.Behavior.Data{
      name: actor_data.name,
      state: state
    }

    case behavior.act(tick_number, behavior_state) do
      {:ok, new_behavior_data} ->
        IO.puts("Actor #{actor_data.name} acted successfully")
        new_state = %{actor_data | state: new_behavior_data.state}
        {:noreply, new_state}

      {:error, reason} ->
        IO.puts("Actor #{actor_data.name} failed to act: #{reason}")
        {:noreply, actor_data}
    end
  end

  defp via_tuple(name), do: {:via, Registry, {Beamulacrum.ActorRegistry, name}}
end
