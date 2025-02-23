defmodule Beamulator.Behaviors.Scanner do
  use Beamulator.Behavior

  # alias Beamulator.ActionExecutor
  # alias Beamulator.Actions
  alias Beamulator.Tools
  # alias Beamulator.Tools.Time

  @impl Beamulator.Behavior
  def default_state() do
    %{
      wait_ticks: 1000
    }
  end

  @impl Beamulator.Behavior
  def act(_tick, %{name: name, state: state} = data) do
    if state.wait_ticks > 0 do
      # Step 1: Wait before scanning
      new_data = %{data | state: %{state | wait_ticks: state.wait_ticks - 1}}
      Logger.debug("Scanner #{name} is waiting to scan (#{new_data.state.wait_ticks} ticks left).")
      {:ok, new_data}
    else
      # Step 2: Scan
      Logger.debug("Scanner #{name} is scanning.")
      big_spender_actors = Tools.Actors.select_by_behavior(Beamulator.Behaviors.BigSpender)
      Logger.debug("Found #{length(big_spender_actors)} big spenders.")

      Logger.debug(:info, "Scanner #{name} found #{length(big_spender_actors)} big spenders.")
      Logger.debug(:info, "Found actors: #{inspect(big_spender_actors)}")
      {:ok, data}
    end
  end
end
