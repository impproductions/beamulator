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
        send(self(), :send_behaviors)
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

    with {:ok, %{"type" => type}} <- Jason.decode(msg) do
      handle_client_message(type, state)
    else
      {:error, _} ->
        Logger.error("Failed to decode message: #{msg}")
        {:ok, state}

      _ ->
        Logger.error("Unable to process message: #{msg}")
        {:ok, state}
    end
  end

  @impl true
  def websocket_handle(_data, state), do: {:ok, state}

  defp handle_client_message("get_behaviors", state) do
    send(self(), :send_behaviors)
    {:ok, state}
  end

  defp handle_client_message("get_actors", state) do
    send(self(), :send_actors)
    {:ok, state}
  end

  defp handle_client_message("heartbeat", state) do
    Logger.debug("Received heartbeat")
    {:ok, state}
  end

  defp handle_client_message(_, state) do
    Logger.error("Unknown message type")
    {:ok, state}
  end

  @impl true
  def websocket_info(:refresh, state) do
    json_message =
      %{
        type: "simulation",
        data: fetch_time_data()
      }
      |> Jason.encode!()

    Process.send_after(self(), :refresh, 250)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info(:send_behaviors, state) do
    behaviors = fetch_behaviors()

    payload = %{
      type: "behaviors",
      behaviors: behaviors
    }

    Logger.info("Sending behaviors: #{inspect(payload)}")
    json_message = Jason.encode!(payload)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info(:send_actors, state) do
    payload = %{
      type: "actors",
      actors: fetch_actors()
    }

    json_message = Jason.encode!(payload)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info({:actor_state_update, actor_state}, state) do
    payload = %{
      type: "actor_state_update",
      actor_state: format_actor_state(actor_state)
    }

    json_message = Jason.encode!(payload)
    {:reply, {:text, json_message}, state}
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
    list = Tools.Actors.select_all()

    list
    |> Enum.group_by(fn {_, {b, _, _}} -> inspect(b) end)
    |> Enum.map(fn {b, actors} ->
      %{
        name: b,
        count: Enum.count(actors),
        actors: Enum.map(actors, fn {_, {_, n, _}} -> n end)
      }
    end)
  end

  defp fetch_actors do
    list = Tools.Actors.select_all()

    list
    |> Enum.map(fn {_, {_, n, _}} -> n end)
  end

  defp fetch_time_data do
    start_time = Clock.get_start_time()
    start_time_ms = start_time |> DateTime.to_unix(:millisecond)
    simulation_ms = Clock.get_simulation_duration_ms()
    simulation_now = start_time_ms + simulation_ms
    real_ms = Clock.get_real_duration_ms()
    simulation_duration = Tools.Time.as_duration_human(simulation_ms, :shorten)
    real_duration = Tools.Time.as_duration_human(real_ms, :shorten)

    %{
      real_ms: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
      simulation_ms: simulation_now,
      simulation_duration: simulation_duration,
      real_duration: real_duration
    }
  end

  defp format_actor_state(actor_state) do
    %{
      serial_id: actor_state.serial_id,
      behavior: strip_namespace(actor_state.behavior),
      name: actor_state.name,
      action_count: actor_state.action_count,
      last_action_time: Tools.Time.as_duration_human(actor_state.last_action_time),
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
