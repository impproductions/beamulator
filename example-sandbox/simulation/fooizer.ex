defmodule Beamulator.Behaviors.Fooizer do
  use Beamulator.Behavior
  require Logger

  @impl Beamulator.Behavior
  def default_state() do
    %{}
  end

  @impl Beamulator.Behavior
  def act(tick, data) do
    %{name: name} = data
    Logger.info("#{name} is acting on tick #{tick}")
    {:ok, 20, data}
  end
end
