defmodule Beamulator.WebSocketHandler do
  require Logger
  alias Beamulator.Tools
  alias Beamulator.Clock
  @behaviour :cowboy_websocket

  @impl true
  def init(req, _) do
    state = %{}
    state = Map.put(state, :displayed_actor, nil)
    {:cowboy_websocket, req, state}
  end

  def broadcast(msg) do
    Registry.lookup(Beamulator.WebsocketRegistry, :connections)
    |> Enum.each(fn {conn, _} -> send(conn, msg) end)
  end

  @impl true
  def websocket_init(state) do
    Logger.info("WebSocket connection established")
    Registry.register(Beamulator.WebsocketRegistry, :connections, self())
    send(self(), {:send_behaviors, get_behaviors()})
    {:ok, state}
  end

  defp get_behaviors do
    list = Manage.actor_list()
    Logger.info("Actor list: #{inspect(list)}")

    list
    |> Enum.group_by(fn {b, _, _, _} -> inspect(b) end)
    |> Enum.map(fn {b, actors} ->
      %{
        name: b,
        count: Enum.count(actors),
        actors: actors |> Enum.map(fn {_, _, n, _} -> n end)
      }
    end)
  end

  # When a client sends a "set_displayed_actor" message, update the state and reply with the actor's state.
  @impl true
  def websocket_handle({:text, msg}, state) do
    Logger.info("Received message: #{msg}")

    case Jason.decode(msg) do
      {:ok, %{"type" => "set_displayed_actor", "actor" => actor}} ->
        Logger.info("Setting displayed actor to: #{actor}")

        # Lookup the actor by name (assumes select_by_name returns a list of {pid, _} tuples)
        {pid, _} =
          Tools.Actors.select_by_name(actor)
          |> Enum.at(0)

        Logger.info("Found actor PID: #{inspect(pid)}")
        actual_actor_state = Manage.actor_state(inspect(pid))
        Logger.info("Actual actor state: #{inspect(actual_actor_state)}")
        state = Map.put(state, :displayed_actor, actual_actor_state)

        payload = %{
          type: "actor_state_update",
          actor_state: format_actor_state(actual_actor_state)
        }

        json_message = Jason.encode!(payload)
        {:reply, {:text, json_message}, state}

      _ ->
        Logger.info("Received unknown message: #{msg}")
        {:ok, state}
    end
  end

  @impl true
  def websocket_handle(_data, state), do: {:ok, state}

  @impl true
  def websocket_info({:send_behaviors, behaviors}, state) do
    payload = %{
      type: "behaviors",
      behaviors: behaviors
    }

    Logger.info("Sending behaviors: #{inspect(payload)}")
    json_message = Jason.encode!(payload)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info(:tick, state) do
    data = gather_tick_data()
    json_message = Jason.encode!(data)
    Process.send_after(self(), :tick, 1000)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info({:action_start, actor_state}, state) do
    payload = %{
      type: "action_start",
      actor_name: actor_state.name
    }

    json_message = Jason.encode!(payload)
    Logger.debug("Sending action start: #{json_message}")
    {:reply, {:text, json_message}, state}
  end

  # Only send actor_state_update if it matches the displayed actor.
  @impl true
  def websocket_info({:actor_state_update, actor_state}, state) do
    if state.displayed_actor == actor_state.name do
      payload = %{
        type: "actor_state_update",
        actor_state: format_actor_state(actor_state)
      }

      json_message = Jason.encode!(payload)
      Logger.debug("Sending actor state update for displayed actor: #{json_message}")
      {:reply, {:text, json_message}, state}
    else
      {:ok, state}
    end
  end

  @impl true
  def websocket_info(info, state) do
    Logger.info("Sending info: #{inspect(info)}")
    {:reply, {:text, inspect(info)}, state}
  end

  @impl true
  def terminate(reason, req, _state) do
    Logger.info("WebSocket connection terminated with reason: #{inspect(reason)} req: #{inspect(req)}")
    :ok
  end

  defp gather_tick_data() do
    tick_number = Clock.get_tick_number()
    duration = Tools.Time.as_duration(tick_number, :shorten)
    tps = Clock.get_tps()
    %{tick_number: tick_number, duration: duration, tps: tps}
  end

  defp format_actor_state(actor_state) do
    %{
      behavior: strip_namespace(actor_state.behavior),
      name: actor_state.name,
      state: actor_state.state,
      config: actor_state.config,
      started: actor_state.started
    }
  end

  defp strip_namespace(behavior) do
    behavior
    |> Atom.to_string()
    |> String.split(".")
    |> tl()
    |> Enum.join(".")
  end
end
