defmodule IngestBackend.QuestDBWriter do
  @moduledoc """
  Persistent TCP connection to QuestDB's ILP port. Accepts ILP iodata and
  writes it. Reconnects with backoff on socket errors.

  ILP line format used here:
    sensor_reading,collector=Collector-1,sensor=42,metric=temperature value=21.5 1700000000000000000\n
  """

  use GenServer
  require Logger

  @reconnect_backoff_ms 2_000

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def write(iodata) when is_list(iodata) or is_binary(iodata) do
    GenServer.call(__MODULE__, {:write, iodata})
  end

  @impl true
  def init(_), do: {:ok, %{socket: nil}, {:continue, :connect}}

  @impl true
  def handle_continue(:connect, state), do: {:noreply, connect(state)}

  @impl true
  def handle_call({:write, iodata}, _from, %{socket: nil} = state) do
    state = connect(state)

    case state.socket do
      nil -> {:reply, {:error, :no_connection}, state}
      sock -> do_send(sock, iodata, state)
    end
  end

  def handle_call({:write, iodata}, _from, %{socket: sock} = state) do
    do_send(sock, iodata, state)
  end

  @impl true
  def handle_info(:reconnect, state), do: {:noreply, connect(state)}

  def handle_info({:tcp_closed, _sock}, state) do
    Logger.warning("QuestDB ILP socket closed; will reconnect on next write")
    {:noreply, %{state | socket: nil}}
  end

  def handle_info({:tcp_error, _sock, reason}, state) do
    Logger.warning("QuestDB ILP socket error #{inspect(reason)}; will reconnect on next write")
    {:noreply, %{state | socket: nil}}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp do_send(sock, iodata, state) do
    case :gen_tcp.send(sock, iodata) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.warning("QuestDB ILP send failed: #{inspect(reason)}; reconnecting")
        :gen_tcp.close(sock)
        {:reply, {:error, reason}, %{state | socket: nil}}
    end
  end

  defp connect(state) do
    host = Application.fetch_env!(:ingest_backend, :questdb_host) |> String.to_charlist()
    port = Application.fetch_env!(:ingest_backend, :questdb_ilp_port)

    case :gen_tcp.connect(host, port, [:binary, active: true, packet: 0], 2_000) do
      {:ok, sock} ->
        Logger.info("Connected to QuestDB ILP at #{host}:#{port}")
        %{state | socket: sock}

      {:error, reason} ->
        Logger.warning(
          "QuestDB ILP connect failed (#{inspect(reason)}); retrying in #{@reconnect_backoff_ms}ms"
        )

        Process.send_after(self(), :reconnect, @reconnect_backoff_ms)
        state
    end
  end
end
