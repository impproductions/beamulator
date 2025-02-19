defmodule Beamulacrum.Actor.State do
  @enforce_keys [:name, :tick, :behavior, :data]
  defstruct [:name, :tick, :behavior, :data]

  @type t :: %__MODULE__{
          name: String.t(),
          behavior: module(),
          data: map()
        }
end

defmodule Beamulacrum.Actor do
  use GenServer

  def start_link({name, behavior_module}) do
    IO.puts("Attempting to start actor: #{name} with behavior #{inspect(behavior_module)}")

    initial_state = behavior_module.default_state()

    case GenServer.start_link(__MODULE__, {name, behavior_module, initial_state},
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

  def init({name, behavior_module, initial_state}) do
    IO.puts("Initializing actor: #{name}")

    actor_state = %{
      name: name,
      behavior: behavior_module,
      data: initial_state
    }

    case Registry.register(Beamulacrum.ActorRegistry, :actors, self()) do
      {:ok, _} ->
        IO.puts("Actor #{name} registered successfully in ActorRegistry")

      {:error, reason} ->
        IO.puts("Failed to register actor #{name}: #{inspect(reason)}")
    end

    {:ok, actor_state}
  end

  def handle_info({:tick, tick_number}, %{behavior: behavior, data: data} = actor_state) do
    IO.puts("Actor #{actor_state.name} reacting to simulation tick #{tick_number}")

    behaviour_state = %Beamulacrum.Behavior.State{
      name: actor_state.name,
      data: data
    }

    case behavior.act(tick_number, behaviour_state) do
      {:ok, new_behaviour_state} ->
        IO.puts("Actor #{actor_state.name} acted successfully")
        new_state = %{actor_state | data: new_behaviour_state.data}
        {:noreply, new_state}

      {:error, reason} ->
        IO.puts("Actor #{actor_state.name} failed to act: #{reason}")
        {:noreply, actor_state}
    end
  end

  defp via_tuple(name), do: {:via, Registry, {Beamulacrum.ActorRegistry, name}}
end
