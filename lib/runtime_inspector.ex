defmodule Beamulator.RuntimeInspector do
  @moduledoc """
  Behaviour for read-only inspection of the running simulation. Consumed by the
  dashboard WS handler, the JSON HTTP API, and tests. Default implementation:
  `Beamulator.RuntimeInspectors.InProcess`.
  """

  @callback stats() :: map()
  @callback actors() :: [map()]
  @callback actor(serial_id :: non_neg_integer()) :: {:ok, map()} | {:error, term()}
  @callback roles() :: [map()]
  @callback complaints() :: [map()]

  def stats(), do: impl().stats()
  def actors(), do: impl().actors()
  def actor(serial_id), do: impl().actor(serial_id)
  def roles(), do: impl().roles()
  def complaints(), do: impl().complaints()

  defp impl(),
    do: Application.get_env(:beamulator, :runtime_inspector, Beamulator.RuntimeInspectors.InProcess)
end
