defmodule IngestBackend.Chaos do
  @moduledoc """
  Runtime-toggleable failure injection. Used by the simulation example to
  surface complaints on the collector side when ingestion misbehaves.

  POST /admin/chaos {"error_rate": 0.5, "duration_ms": 30000}

  After duration_ms wall-clock ms, the chaos window closes automatically.
  error_rate is the probability of a single /ingest request being rejected
  with 503.
  """

  use GenServer
  require Logger

  defstruct error_rate: 0.0, expires_at_ms: 0

  def start_link(_), do: GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)

  def set(error_rate, duration_ms) when error_rate >= 0.0 and error_rate <= 1.0 do
    GenServer.call(__MODULE__, {:set, error_rate, duration_ms})
  end

  def status, do: GenServer.call(__MODULE__, :status)

  @doc "Returns true if this request should be dropped (503)."
  def should_drop? do
    case status() do
      %{active: false} -> false
      %{error_rate: r} -> :rand.uniform() < r
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:set, rate, duration_ms}, _from, _state) do
    expires_at = System.system_time(:millisecond) + duration_ms
    Logger.warning("CHAOS ON: error_rate=#{rate} duration_ms=#{duration_ms}")
    {:reply, :ok, %__MODULE__{error_rate: rate, expires_at_ms: expires_at}}
  end

  @impl true
  def handle_call(:status, _from, %{error_rate: r, expires_at_ms: exp} = state) do
    active = System.system_time(:millisecond) < exp and r > 0.0
    {:reply, %{active: active, error_rate: r, expires_at_ms: exp}, state}
  end
end
