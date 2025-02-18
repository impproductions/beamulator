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
    end
  end

  def init({name, behavior_module, initial_state}) do
    IO.puts("Initializing actor: #{name}")

    state = %{
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

    {:ok, state}
  end

  def handle_info({:tick, tick_number}, %{behavior: behavior, data: data} = state) do
    IO.puts("Actor #{state.name} reacting to simulation tick #{tick_number}")

    {decision, updated_data} = behavior.decide(data)
    IO.puts("Picked op: #{decision}, new state: #{inspect(state)}")

    new_state = %{state | data: updated_data}

    {:noreply, new_state}
  end

  defp via_tuple(name), do: {:via, Registry, {Beamulacrum.ActorRegistry, name}}
end
