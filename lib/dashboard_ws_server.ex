defmodule Beamulator.WebSocketHandler do
  require Logger
  alias Beamulator.ActorStatesProvider
  alias Beamulator.Tools
  alias Beamulator.Clock
  @behaviour :cowboy_websocket

  @impl true
  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  @impl true
  def websocket_init(state) do
    Process.send_after(self(), :tick, 1000)
    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, _msg}, state) do
    {:ok, state}
  end

  @impl true
  def websocket_handle(_data, state), do: {:ok, state}

  @impl true
  def websocket_info(:tick, state) do
    data = gather_data(:overview)
    json_message = Jason.encode!(data)

    Process.send_after(self(), :tick, 1000)
    {:reply, {:text, json_message}, state}
  end

  @impl true
  def websocket_info(info, state) do
    {:reply, {:text, inspect(info)}, state}
  end

  @impl true
  def terminate(reason, req, _state) do
    Logger.info(
      "WebSocket connection terminated with reason: #{inspect(reason)} req: #{inspect(req)}"
    )

    :ok
  end

  def gather_data(:overview) do
    tick_number = Clock.get_tick_number()
    duration = tick_number |> Tools.Time.as_duration(:shorten)
    tps = Clock.get_tps()

    actor_counts =
      Manage.actor_list()
      |> Enum.group_by(fn {behavior, _id, _name, _pid} -> behavior end)
      |> Enum.map(fn {behavior, actors} -> [strip_namespace(behavior), length(actors)] end)

    # actor_states =
    actor_states =
      ActorStatesProvider.get_actor_states()
      |> Enum.map(fn {_, state} -> state end)
      |> Enum.map(fn state ->
        %{
          behavior: strip_namespace(state.behavior),
          name: state.name,
          state: state.state,
          config: state.config,
          started: state.started
        }
      end)

    data = %{
      tick_number: tick_number,
      duration: duration,
      tps: tps,
      actor_counts: actor_counts,
      actor_states: actor_states
    }

    data
  end

  defp strip_namespace(behavior) do
    behavior
    |> Atom.to_string()
    |> String.split(".")
    |> tl()
    |> Enum.join(".")
  end
end
