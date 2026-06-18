defmodule Beamulator.Clients.QuestDBUnreachable do
  @behaviour Beamulator.Clients.QuestDB

  @impl true
  def test_connection(_url), do: {:error, :unreachable}

  @impl true
  def exec(_url, _query), do: {:error, :unreachable}

  @impl true
  def write(_url, _payload), do: {:error, :unreachable}
end
