defmodule Beamulator.Clients.QuestDB do
  @moduledoc """
  Behaviour for the framework's QuestDB integration. Real impl: `Beamulator.Clients.QuestDBHttp`.
  Test impls: `Beamulator.Clients.QuestDBFake`, `Beamulator.Clients.QuestDBUnreachable`.
  """

  @type url :: String.t()

  @callback test_connection(url) :: :ok | {:error, term()}
  @callback exec(url, query :: String.t()) :: :ok | {:error, term()}
  @callback write(url, payload :: String.t()) :: :ok | {:error, term()}
end
