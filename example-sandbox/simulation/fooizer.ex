defmodule Beamulacrum.Behaviors.Fooizer do
  use Beamulacrum.Behavior
  require Logger

  @impl Beamulacrum.Behavior
  def default_state() do
    %{}
  end

  @impl Beamulacrum.Behavior
  def act(tick, data) do
    %{name: name} = data
    Logger.info("#{name} is acting on tick #{tick}")
    {:ok, 20, data}
  end
end
