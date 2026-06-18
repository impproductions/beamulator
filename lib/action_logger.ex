defmodule Beamulator.ActionLogger do
  use GenServer
  require Logger

  alias Beamulator.Clock

  @behavior_symbol_capacity 1024
  @action_symbol_capacity 1024
  @severity_symbol_capacity 16

  @default_batch_size 1000
  @default_flush_interval 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    questdb_config = Application.get_env(:beamulator, :questdb)
    url = "#{questdb_config[:url]}:#{questdb_config[:port]}"
    flush_interval = questdb_config[:flush_interval_ms] || @default_flush_interval

    client =
      Keyword.get(
        opts,
        :client,
        Application.get_env(:beamulator, :questdb_client, Beamulator.Clients.QuestDBHttp)
      )

    state = %{
      queue: [],
      flush_timer: nil,
      url: url,
      flush_interval: flush_interval,
      client: client,
      ready: false
    }

    {:ok, try_setup(state)}
  end

  defp try_setup(%{client: client, url: url, flush_interval: flush_interval} = state) do
    with :ok <- client.test_connection(url),
         :ok <- create_tables(client, url) do
      Logger.info("ActionLogger ready against #{url}")
      timer_ref = Process.send_after(self(), :flush, flush_interval)
      %{state | ready: true, flush_timer: timer_ref}
    else
      {:error, reason} ->
        Logger.error("ActionLogger setup failed: #{inspect(reason)}; retrying in #{flush_interval}ms")
        Process.send_after(self(), :retry_setup, flush_interval)
        state
    end
  end

  @impl true
  def handle_info(:retry_setup, %{ready: false} = state), do: {:noreply, try_setup(state)}

  def handle_info(:retry_setup, state), do: {:noreply, state}

  @impl true
  def handle_cast({:log_complaint, _}, %{ready: false} = state) do
    Logger.debug("Dropping complaint: ActionLogger not ready")
    {:noreply, state}
  end

  def handle_cast(
        {:log_complaint, {behavior, actor, message, severity, action, args, actual}},
        state
      ) do
    {line, context} =
      build_complaint_line(%{
        behavior: behavior,
        actor: actor,
        message: message,
        severity: severity,
        action: action,
        args: args,
        actual: actual
      })

    {:noreply, enqueue(state, line, context)}
  end

  @impl true
  def handle_cast({:log_event, _}, %{ready: false} = state) do
    Logger.debug("Dropping event: ActionLogger not ready")
    {:noreply, state}
  end

  def handle_cast({:log_event, {{behavior, name}, action, args, result, success}}, state) do
    {line, context} =
      build_event_line(%{
        behavior: behavior,
        name: name,
        action: action,
        args: args,
        success: success,
        result: result
      })

    {:noreply, enqueue(state, line, context)}
  end

  defp enqueue(state, line, context) do
    new_queue = state.queue ++ [{line, context}]

    flush_batch_size =
      Application.get_env(:beamulator, :questdb)[:flush_batch_size] || @default_batch_size

    state = %{state | queue: new_queue}

    if length(new_queue) >= flush_batch_size do
      if state.flush_timer, do: Process.cancel_timer(state.flush_timer)
      flush(state)
      timer_ref = Process.send_after(self(), :flush, state.flush_interval)
      %{state | queue: [], flush_timer: timer_ref}
    else
      state
    end
  end

  @impl true
  def handle_info(:flush, state) do
    if state.queue != [], do: flush(state)
    timer_ref = Process.send_after(self(), :flush, state.flush_interval)
    {:noreply, %{state | queue: [], flush_timer: timer_ref}}
  end

  defp flush(%{client: client, url: url, queue: queue}) do
    payload =
      queue
      |> Enum.map(fn {line, _context} -> line end)
      |> Enum.join("\n")

    case client.write(url, payload) do
      :ok ->
        Logger.info("Successfully sent #{length(queue)} logs to QuestDB.")

      {:error, reason} ->
        Enum.each(queue, fn {_, context} ->
          Logger.error("Failed to send log for #{context}: #{inspect(reason)}")
        end)
    end
  end

  defp create_tables(client, url) do
    Logger.info("Creating log and metadata tables...")

    ddls = [
      {
        "action_log",
        """
        CREATE TABLE IF NOT EXISTS action_log (
          timestamp TIMESTAMP,
          behavior SYMBOL CAPACITY #{@behavior_symbol_capacity} NOCACHE,
          name STRING,
          action SYMBOL CAPACITY #{@action_symbol_capacity} NOCACHE,
          args STRING,
          success BOOLEAN,
          result STRING,
          real_time TIMESTAMP,
          start_time TIMESTAMP
        ) TIMESTAMP(timestamp)
        PARTITION BY DAY
        TTL 1 WEEK
        WAL
        """
      },
      {
        "run_metadata",
        """
        CREATE TABLE IF NOT EXISTS run_metadata (
          timestamp TIMESTAMP,
          run_id STRING,
          actions_file STRING,
          random_seed INT
        ) TIMESTAMP(timestamp)
        """
      },
      {
        "complaints_log",
        """
        CREATE TABLE IF NOT EXISTS complaints_log (
          timestamp TIMESTAMP,
          behavior SYMBOL CAPACITY #{@behavior_symbol_capacity} NOCACHE,
          actor STRING,
          message STRING,
          severity SYMBOL CAPACITY #{@severity_symbol_capacity} NOCACHE,
          action SYMBOL CAPACITY #{@action_symbol_capacity} NOCACHE,
          args STRING,
          result STRING,
          trigger STRING,
          start_time TIMESTAMP,
          run_id STRING
        ) TIMESTAMP(timestamp)
        PARTITION BY DAY
        TTL 1 WEEK
        WAL
        """
      }
    ]

    Enum.reduce_while(ddls, :ok, fn {table, ddl}, _acc ->
      case client.exec(url, ddl) do
        :ok ->
          Logger.info("Table #{table} created or verified.")
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok ->
        fill_metadata_table(client, url)
        :ok

      err ->
        err
    end
  end

  defp fill_metadata_table(client, url) do
    run_id = Application.get_env(:beamulator, :run_uuid)
    simulation_config = Application.get_env(:beamulator, :simulation)
    random_seed = simulation_config[:random_seed]

    actions_file = Beamulator.Actions.source_code() |> Base.encode64()

    timestamp_ns = DateTime.utc_now() |> DateTime.to_unix(:nanosecond)

    line =
      "run_metadata,run_id=#{run_id} " <>
        "actions_file=\"#{actions_file}\",random_seed=#{random_seed} " <>
        "#{timestamp_ns}"

    case client.write(url, line) do
      :ok -> Logger.info("Metadata successfully sent to QuestDB.")
      {:error, reason} -> Logger.error("Failed to send metadata to QuestDB: #{inspect(reason)}")
    end
  end

  defp build_complaint_line(data) do
    %{
      behavior: behavior,
      actor: actor,
      message: message,
      severity: severity,
      action: action,
      args: args,
      actual: actual
    } = data

    action_str = inspect(action) |> escape_tag()
    args_str = Jason.encode!(args) |> escape_field()
    trigger_str = actual.trigger |> escape_field()

    actual_str =
      %{status: actual.status, result: actual.result} |> Jason.encode!() |> escape_field()

    severity_str = inspect(severity)

    {timestamp, start_timestamp, _real_time} = compute_timestamps()

    line =
      "complaints_log,behavior=#{escape_tag(behavior)},actor=#{escape_tag(actor)},severity=#{escape_tag(severity_str)} " <>
        "message=\"#{message}\",action=\"#{escape_field(action_str)}\",args=\"#{args_str}\",result=\"#{actual_str}\",trigger=\"#{trigger_str}\"," <>
        "start_time=#{start_timestamp}i,run_id=\"#{Application.get_env(:beamulator, :run_uuid)}\" " <>
        "#{timestamp}"

    {line, "complaint by #{actor}"}
  end

  defp build_event_line(data) do
    %{behavior: behavior, name: name, action: action, args: args, result: result} = data
    {status, content} = result

    action_str = inspect(action) |> escape_tag()
    args_str = Jason.encode!(args) |> escape_field()
    result_str = %{status: status, content: content} |> Jason.encode!() |> escape_field()
    success = if status == :ok, do: "true", else: "false"

    {timestamp, start_timestamp, real_time} = compute_timestamps()

    line =
      "action_log,behavior=#{escape_tag(behavior)},name=#{escape_tag(name)},action=#{escape_tag(action_str)} " <>
        "args=\"#{args_str}\",result=\"#{result_str}\",real_time=#{real_time}i," <>
        "start_time=#{start_timestamp}i,run_id=\"#{Application.get_env(:beamulator, :run_uuid)}\",success=#{success} " <>
        "#{timestamp}"

    {line, "action #{action_str} by #{name}"}
  end

  defp compute_timestamps() do
    start_time = Clock.get_start_time()
    simulation_time_ns = Clock.get_simulation_duration_ms() * 1_000_000

    timestamp_ns = DateTime.to_unix(start_time, :nanosecond) + simulation_time_ns
    start_timestamp_us = DateTime.to_unix(start_time, :microsecond)
    real_time_us = Clock.get_real_duration_ms() * 1_000 + start_timestamp_us
    {timestamp_ns, start_timestamp_us, real_time_us}
  end

  defp escape_tag(tag) when is_binary(tag), do: String.replace(tag, ~r/[\s,=]/, "_")
  defp escape_tag(tag), do: tag |> to_string() |> escape_tag()

  defp escape_field(field) when is_binary(field) do
    field
    |> String.replace(~s("), ~s(\\"))
    |> String.replace("\n", "\\n")
  end
end
