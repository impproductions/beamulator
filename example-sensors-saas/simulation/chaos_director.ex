defmodule Beamulator.Roles.ChaosDirector do
  @moduledoc """
  Periodically flips the backend's chaos switch on/off via /admin/chaos.

  Showcases the "network partition" failure mode: when chaos is on, the
  backend drops a fraction of /ingest requests with 503, which propagates to
  collectors and fires their `backend_outage` complaint.

  Cycle (in simulation time, with the default 200x multiplier):
    * Idle window: ~10 simulated minutes (3 real seconds)
    * Outage window: ~45 simulated seconds at 60% error rate (~225 real ms)
  """

  alias Beamulator.Actions
  alias Beamulator.Lab.Duration, as: D
  use Beamulator.Role
  require Logger

  expose_actions [
    {:toggle_backend_chaos, default_args: [%{error_rate: 0.6, duration_ms: 30_000}]}
  ]

  @impl true
  def default_tags(), do: MapSet.new()

  @impl true
  def default_state(), do: %{chaos_on?: false}

  @impl true
  def act(%{actor_state: state} = actor_data) do
    {next_state, wait} =
      if state.chaos_on? do
        execute(actor_data, &Actions.toggle_backend_chaos/1, %{error_rate: 0.0, duration_ms: 0})
        {%{state | chaos_on?: false}, D.new(m: 10)}
      else
        execute(actor_data, &Actions.toggle_backend_chaos/1, %{
          error_rate: 0.6,
          duration_ms: 30_000
        })

        {%{state | chaos_on?: true}, D.new(s: 45)}
      end

    {:ok, wait, %{actor_data | actor_state: next_state}}
  end
end
