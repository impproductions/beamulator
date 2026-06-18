defmodule Beamulator.Clock do
  alias Beamulator.Utils
  use GenServer
  require Logger

  def start_link(opts) when is_list(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Logger.debug("Starting clock process (#{inspect(name)})")
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def start_link(_), do: start_link([])

  def mode(server \\ __MODULE__), do: GenServer.call(server, :mode)

  def get_start_time(server \\ __MODULE__),
    do: GenServer.call(server, :get_start_time)

  def get_real_duration_ms(server \\ __MODULE__),
    do: GenServer.call(server, :get_real_duration_ms)

  def get_simulation_now(server \\ __MODULE__),
    do: GenServer.call(server, :get_simulation_now)

  def get_simulation_duration_ms(server \\ __MODULE__),
    do: GenServer.call(server, :get_simulation_duration_ms)

  def advance(server \\ __MODULE__, amount_ms) when is_integer(amount_ms) and amount_ms >= 0,
    do: GenServer.call(server, {:advance, amount_ms})

  def set_now(server \\ __MODULE__, unix_ms) when is_integer(unix_ms),
    do: GenServer.call(server, {:set_now, unix_ms})

  def schedule_at(pid, message, due_ms)
      when is_pid(pid) and is_integer(due_ms),
      do: schedule_at(__MODULE__, pid, message, due_ms)

  def schedule_at(server, pid, message, due_ms)
      when is_pid(pid) and is_integer(due_ms),
      do: GenServer.call(server, {:schedule_at, pid, message, due_ms})

  def init(opts) do
    config_mode = Application.fetch_env!(:beamulator, :simulation)[:clock_mode] || :auto
    mode = Keyword.get(opts, :mode, config_mode)

    start_time =
      cond do
        Keyword.has_key?(opts, :start_time) -> Keyword.fetch!(opts, :start_time)
        Application.get_env(:beamulator, :start_time) -> Application.get_env(:beamulator, :start_time)
        true -> DateTime.utc_now()
      end

    Application.put_env(:beamulator, :start_time, start_time)

    Logger.info("Clock initialized at #{DateTime.to_iso8601(start_time)} (mode: #{mode})")

    start_unix_ms = DateTime.to_unix(start_time, :millisecond)

    state = %{
      start_time: start_time,
      start_unix_ms: start_unix_ms,
      mode: mode,
      now_ms: start_unix_ms,
      scheduled: []
    }

    {:ok, state}
  end

  def handle_call(:mode, _from, state), do: {:reply, state.mode, state}

  def handle_call(:get_start_time, _from, state), do: {:reply, state.start_time, state}

  def handle_call(:get_simulation_now, _from, %{mode: :manual} = state),
    do: {:reply, state.now_ms, state}

  def handle_call(:get_simulation_now, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, state.start_unix_ms + Utils.Time.ms_to_simulation_ms(since_start), state}
  end

  def handle_call(:get_simulation_duration_ms, _from, %{mode: :manual} = state),
    do: {:reply, state.now_ms - state.start_unix_ms, state}

  def handle_call(:get_simulation_duration_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, Utils.Time.ms_to_simulation_ms(since_start), state}
  end

  def handle_call(:get_real_duration_ms, _from, %{mode: :manual} = state) do
    {:reply, Utils.Time.simulation_ms_to_ms(state.now_ms - state.start_unix_ms), state}
  end

  def handle_call(:get_real_duration_ms, _from, state) do
    since_start = DateTime.diff(DateTime.utc_now(), state.start_time, :millisecond)
    {:reply, since_start, state}
  end

  def handle_call({:advance, amount_ms}, _from, %{mode: :manual} = state) do
    {:reply, :ok, dispatch_due(%{state | now_ms: state.now_ms + amount_ms})}
  end

  def handle_call({:advance, _}, _from, state) do
    {:reply, {:error, :auto_mode}, state}
  end

  def handle_call({:set_now, unix_ms}, _from, %{mode: :manual} = state) do
    {:reply, :ok, dispatch_due(%{state | now_ms: unix_ms})}
  end

  def handle_call({:set_now, _}, _from, state) do
    {:reply, {:error, :auto_mode}, state}
  end

  def handle_call({:schedule_at, pid, message, due_ms}, _from, %{mode: :manual} = state) do
    entry = {due_ms, pid, message}
    scheduled = insert_sorted(state.scheduled, entry)
    {:reply, :ok, %{state | scheduled: scheduled}}
  end

  def handle_call({:schedule_at, _, _, _}, _from, state) do
    {:reply, {:error, :auto_mode}, state}
  end

  defp insert_sorted([], entry), do: [entry]

  defp insert_sorted([{head_due, _, _} = head | tail], {due, _, _} = entry) when due < head_due,
    do: [entry, head | tail]

  defp insert_sorted([head | tail], entry), do: [head | insert_sorted(tail, entry)]

  defp dispatch_due(%{now_ms: now_ms, scheduled: scheduled} = state) do
    {due, remaining} = Enum.split_while(scheduled, fn {due_ms, _, _} -> due_ms <= now_ms end)
    Enum.each(due, fn {_, pid, message} -> send(pid, message) end)
    %{state | scheduled: remaining}
  end
end
