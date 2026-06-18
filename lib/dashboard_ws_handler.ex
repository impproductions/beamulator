defmodule Beamulator.Dashboard.WebSocketHandler do
  require Logger
  alias Beamulator.Utils
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
        send(self(), :send_roles)
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

    with {:ok, %{"type" => _type} = decoded} <- Jason.decode(msg) do
      handle_client_message(decoded, state)
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

  defp handle_client_message(%{"type" => "get_roles"}, state) do
    send(self(), :send_roles)
    {:ok, state}
  end

  defp handle_client_message(%{"type" => "get_actors"}, state) do
    send(self(), :send_actors)
    {:ok, state}
  end

  defp handle_client_message(%{"type" => "heartbeat"}, state) do
    Logger.debug("Received heartbeat")
    {:ok, state}
  end

  defp handle_client_message(%{"type" => "get_actions", "role" => role}, state) do
    payload = %{
      type: "actions",
      role: role,
      actions: Beamulator.RuntimeInspector.actions_for(role)
    }

    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  defp handle_client_message(
         %{"type" => "invoke_action", "serial_id" => serial_id, "action" => action} = msg,
         state
       )
       when is_integer(serial_id) and is_binary(action) do
    args = Map.get(msg, "args")
    result = Beamulator.Lab.Actor.invoke(serial_id, action, args)

    {success, payload_result} =
      case result do
        {:ok, {:ok, value}} -> {true, %{ok: encode_result(value)}}
        {:ok, {:error, reason}} -> {false, %{error: encode_result(reason)}}
        {:error, reason} -> {false, %{error: inspect(reason)}}
      end

    payload = %{
      type: "invoke_result",
      serial_id: serial_id,
      action: action,
      success: success,
      result: payload_result
    }

    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  defp handle_client_message(_, state) do
    Logger.error("Unknown message type")
    {:ok, state}
  end

  defp encode_result(v) when is_binary(v) or is_number(v) or is_boolean(v) or is_nil(v), do: v
  defp encode_result(v) when is_list(v), do: Enum.map(v, &encode_result/1)
  defp encode_result(v) when is_map(v) and not is_struct(v) do
    for {k, val} <- v, into: %{}, do: {to_string(k), encode_result(val)}
  end
  defp encode_result(v), do: inspect(v)

  @impl true
  def websocket_info(:refresh, state) do
    json_message =
      %{
        type: "simulation",
        data: fetch_time_data(),
        stats: fetch_stats()
      }
      |> Jason.encode!()

    Process.send_after(self(), :refresh, 250)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info(:send_roles, state) do
    roles = fetch_roles()

    payload = %{
      type: "roles",
      roles: roles
    }

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
  def websocket_info({:manual_action_trigger, serial_id, action_name}, state) do
    payload = %{
      type: "manual_action_trigger",
      serial_id: serial_id,
      action: action_name
    }

    {:reply, {:text, Jason.encode!(payload)}, state}
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

  defp fetch_roles do
    Beamulator.RuntimeInspector.roles()
  end

  defp fetch_actors do
    Beamulator.RuntimeInspector.actors()
    |> Enum.map(& &1.name)
  end

  defp fetch_time_data do
    simulation_ms = Clock.get_simulation_duration_ms()
    simulation_now = Clock.get_simulation_now()
    real_ms = Clock.get_real_duration_ms()
    simulation_duration = Utils.Time.as_duration_human(simulation_ms, :shorten)
    real_duration = Utils.Time.as_duration_human(real_ms, :shorten)

    %{
      real_ms: DateTime.utc_now() |> DateTime.to_string(),
      simulation_ms: simulation_now,
      simulation_duration: simulation_duration,
      real_duration: real_duration
    }
  end

  defp format_actor_state(actor_state) do
    %{
      serial_id: actor_state.serial_id,
      pid: actor_state.pid_str,
      role: strip_namespace(actor_state.role),
      tags: MapSet.to_list(actor_state.tags),
      name: actor_state.name,
      action_count: actor_state.runtime_stats.action_count,
      last_action_time:
        DateTime.from_unix!(actor_state.runtime_stats.last_action_time, :millisecond)
        |> DateTime.to_string(),
      next_action_time:
        DateTime.from_unix!(actor_state.runtime_stats.next_action_time, :millisecond)
        |> DateTime.to_string(),
      state: inspect(actor_state.state, pretty: true),
      config: inspect(actor_state.config, pretty: true),
      started: actor_state.runtime_stats.started
    }
  end

  def fetch_stats do
    Beamulator.RuntimeInspector.stats()
  end

  defp strip_namespace(role) do
    role
    |> Atom.to_string()
    |> String.split(".")
    |> tl()
    |> Enum.join(".")
  end
end
