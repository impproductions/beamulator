defmodule Beamulator.DashboardStatsProvider do
  require Logger
  defstruct Stats: %{
              actions_total: 0,
              actions_per_second_overall: 0,
              actions_successful: 0,
              actions_failed: 0,
              actors_crashes: 0
            }

  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec get_stats() :: Stats
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @impl true
  def init(_opts) do
    state = %{
      start_time: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
      actions_total: 0,
      actions_per_second_overall: 0,
      actions_successful: 0,
      actions_failed: 0,
      actors_crashes: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:action, success}, state) do
    elapsed = (DateTime.utc_now() |> DateTime.to_unix(:millisecond)) - state.start_time

    state = %{
      state
      | actions_total: state.actions_total + 1,
        actions_successful: state.actions_successful + (if (success), do: 1, else: 0),
        actions_failed: state.actions_failed + (if (success), do: 0, else: 1),
        actions_per_second_overall: Float.round(state.actions_total / elapsed * 1000, 2)
    }

    {:noreply, state}
  end

  @impl true
  def handle_cast({:actor, :crash}, state) do
    state = %{
      state
      | actors_crashes: state.actors_crashes + 1
    }

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    elapsed = (DateTime.utc_now() |> DateTime.to_unix(:millisecond)) - state.start_time
    stats = %{
      actions_total: state.actions_total,
      actions_successful: state.actions_successful,
      actions_per_second_overall: Float.round(state.actions_total / elapsed * 1000, 2),
      actions_failed: state.actions_failed,
      actors_crashes: state.actors_crashes
    }

    {:reply, stats, state}
  end
end
