defmodule Beamulator.Dashboard.WebSocketHandler do
  require Logger
  alias Beamulator.Tools
  alias Beamulator.Clock
  @behaviour :cowboy_websocket

  @impl true
  def init(req, _opts) do
    state = %{displayed_actor: nil}
    {:cowboy_websocket, req, state}
  end

  def broadcast(msg) do
    Registry.lookup(Beamulator.WebsocketRegistry, :connections)
    |> Enum.each(fn {conn, _} -> send(conn, msg) end)
  end

  @impl true
  def websocket_init(state) do
    Logger.info("WebSocket connection established")

    case Registry.register(Beamulator.WebsocketRegistry, :connections, self()) do
      {:ok, _} ->
        send(self(), {:send_behaviors, fetch_behaviors()})
        send(self(), :refresh)
        {:ok, state}

      {:error, _} ->
        Logger.error("Failed to register connection")
        {:error, :shutdown}
    end
  end

  @impl true
  def websocket_handle({:text, msg}, state) do
    Logger.info("Received message: #{msg}")

    case Jason.decode(msg) do
      {:ok, %{"type" => "set_displayed_actor", "actor" => actor}} ->
        Logger.info("Setting displayed actor to: #{actor}")

        {pid, _} =
          Tools.Actors.select_by_name(actor)
          |> Enum.at(0)

        Logger.info("Found actor PID: #{inspect(pid)}")
        actual_actor_state = Tools.Actors.get_state(pid)
        Logger.info("Actual actor state: #{inspect(actual_actor_state)}")
        state = Map.put(state, :displayed_actor, actual_actor_state.name)

        payload = %{
          type: "actor_state_update",
          actor_state: format_actor_state(actual_actor_state)
        }

        json_message = Jason.encode!(payload)
        {:reply, {:text, json_message}, state}

      {:ok, %{"type" => "heartbeat"}} ->
        Logger.debug("Received heartbeat")
        {:ok, state}

      _ ->
        Logger.info("Received unknown message: #{msg}")
        {:ok, state}
    end
  end

  @impl true
  def websocket_handle(_data, state), do: {:ok, state}

  @impl true
  def websocket_info(:refresh, state) do
    json_message =
      %{
        type: "simulation",
        data: fetch_tick_data()
      }
      |> Jason.encode!()

    Process.send_after(self(), :refresh, 250)
    {:reply, {:text, json_message}, state}
  end

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
      Logger.warning(
        "Not sending actor state update for non-displayed actor: #{inspect(actor_state.name)} (displayed: #{inspect(state.displayed_actor)})"
      )

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
    Logger.info(
      "WebSocket connection terminated with reason: #{inspect(reason)} req: #{inspect(req)}"
    )

    :ok
  end

  defp fetch_behaviors do
    list = Manage.actor_list()
    Logger.info("Actor list: #{inspect(list)}")

    list
    |> Enum.group_by(fn {b, _, _, _} -> inspect(b) end)
    |> Enum.map(fn {b, actors} ->
      %{
        name: b,
        count: Enum.count(actors),
        actors: Enum.map(actors, fn {_, _, n, _} -> n end)
      }
    end)
  end

  defp fetch_tick_data do
    tick_number = Clock.get_tick_number()
    duration = Tools.Time.as_duration_human(tick_number, :shorten)
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
