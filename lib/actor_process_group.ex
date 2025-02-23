defmodule Beamulacrum.ActorProcessGroup do
  require Logger

  def join() do
    Logger.debug("Actor #{inspect(self())} joining group #{:actor_group}")

    :ok = :pg.join(:actor, :actor_group, self())
    Logger.debug("Actor #{inspect(self())} joined group #{:actor_group}")
  end

  def broadcast(message) do
    for pid <- :pg.get_members(:actor, :actor_group), do: GenServer.cast(pid, message)
  end
end
