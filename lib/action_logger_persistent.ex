defmodule Beamulator.ActionLoggerPersistent do
  @moduledoc """
  A persistent logger for actions and complaints that writes to QuestDB.
  """

  use GenServer
  require Logger

  alias Beamulator.Tools
  alias Beamulator.Clock

  @headers [{"Content-Type", "application/json"}, {"Accept", "application/json"}]
  @write_headers [{"Content-Type", "text/plain"}]
  @write_url "http://localhost:9000/write"

  @behavior_symbol_capacity 1024
  @action_symbol_capacity 1024
  @severity_symbol_capacity 16

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    questdb_config = Application.get_env(:beamulator, :questdb)
    url = "#{questdb_config[:url]}:#{questdb_config[:port]}"

    with :ok <- test_connection(url),
         :ok <- create_tables(url) do
      {:ok, %{}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:log_complaint, {behavior, actor, message, severity, action, args, actual}}, state) do
    write_complaint(%{
      behavior: behavior,
      actor: actor,
      message: message,
      severity: severity,
      action: action,
      args: args,
      actual: actual
    })

    {:noreply, state}
  end

  @impl true
  def handle_cast({:log_event, {{behavior, name}, action, args, result}}, state) do
    write_event(%{
      behavior: behavior,
      name: name,
      action: action,
      args: args,
      result: result
    })

    {:noreply, state}
  end

  defp test_connection(url) do
    Logger.debug("Testing connection to QuestDB at #{url}")

    uri =
      URI.new!(url <> "/exec")
      |> URI.append_query(URI.encode_query(exec: "SELECT 1"))
      |> URI.to_string()

    case HTTPoison.get(uri, @headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Successfully connected to QuestDB.")
        :ok

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status #{code}. Body: #{body}")
        {:error, body}

      {:error, reason} ->
        Logger.error("Failed to connect to QuestDB: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_tables(url) do
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
          result STRING,
          tick_number DOUBLE,
          tick_interval DOUBLE,
          start_time TIMESTAMP
        ) TIMESTAMP(timestamp)
        PARTITION BY DAY
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
        WAL
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
        WAL
        """
      }
    ]

    for {table, ddl} <- ddls do
      uri =
        URI.new!(url <> "/exec")
        |> URI.append_query(URI.encode_query(query: ddl))
        |> URI.to_string()

      HTTPoison.get!(uri, @headers)
      Logger.info("Table #{table} created or verified.")
    end

    fill_metadata_table()
    :ok
  end

  defp fill_metadata_table() do
    run_id = Application.get_env(:beamulator, :run_uuid)
    simulation_config = Application.get_env(:beamulator, :simulation)
    random_seed = simulation_config[:random_seed]

    actions_file = Beamulator.Actions.source_code() |> Base.encode64()

    timestamp_ns = DateTime.utc_now() |> DateTime.to_unix(:nanosecond)
    line =
      "run_metadata,run_id=#{run_id} " <>
        "actions_file=\"#{actions_file}\",random_seed=#{random_seed} " <>
        "#{timestamp_ns}"

    case HTTPoison.post(@write_url, line, @write_headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Metadata successfully sent to QuestDB.")
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status #{code} on metadata. Body: #{body}")
        Logger.debug("Failed line: #{line}")
      {:error, reason} ->
        Logger.error("Failed to send metadata to QuestDB: #{inspect(reason)}")
        Logger.debug("Failed line: #{line}")
    end
  end

  defp write_complaint(data) do
    %{behavior: behavior, actor: actor, message: message, severity: severity,
      action: action, args: args, actual: actual} = data

    action_str = inspect(action) |> escape_tag()
    args_str = Jason.encode!(args) |> escape_field()
    trigger_str = actual.trigger |> escape_field()
    actual_str = %{status: actual.status, result: actual.result} |> Jason.encode!() |> escape_field()
    severity_str = inspect(severity)

    {timestamp, start_timestamp, _tick_number} = compute_timestamps()

    line =
      "complaints_log,behavior=#{escape_tag(behavior)},actor=#{escape_tag(actor)},severity=#{escape_tag(severity_str)} " <>
        "message=\"#{message}\",action=\"#{escape_field(action_str)}\",args=\"#{args_str}\",result=\"#{actual_str}\",trigger=\"#{trigger_str}\"," <>
        "start_time=#{start_timestamp}i,run_id=\"#{Application.get_env(:beamulator, :run_uuid)}\" " <>
        "#{timestamp}"

    post_line(line, "complaint by #{actor}")
  end

  defp write_event(data) do
    %{behavior: behavior, name: name, action: action, args: args, result: result} = data
    {status, content} = result

    action_str = inspect(action) |> escape_tag()
    args_str = Jason.encode!(args) |> escape_field()
    result_str = %{status: status, content: content} |> Jason.encode!() |> escape_field()

    tick_interval = Tools.Time.tick_interval_ms()
    {timestamp, start_timestamp, tick_number} = compute_timestamps()

    line =
      "action_log,behavior=#{escape_tag(behavior)},name=#{escape_tag(name)},action=#{escape_tag(action_str)} " <>
        "args=\"#{args_str}\",result=\"#{result_str}\",tick_number=#{tick_number},tick_interval=#{tick_interval}," <>
        "start_time=#{start_timestamp}i,run_id=\"#{Application.get_env(:beamulator, :run_uuid)}\" " <>
        "#{timestamp}"

    post_line(line, "action #{action_str} by #{name}")
  end

  defp compute_timestamps() do
    tick_number = Clock.get_tick_number()
    start_time = Clock.get_start_time()
    tick_interval = Tools.Time.tick_interval_ms()

    tick_duration_ns = tick_number * tick_interval * 10_000
    timestamp = DateTime.to_unix(start_time, :nanosecond) + tick_duration_ns
    start_timestamp = DateTime.to_unix(start_time, :microsecond)
    {timestamp, start_timestamp, tick_number}
  end

  defp post_line(line, context) do
    case HTTPoison.post(@write_url, line, @write_headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Successfully logged #{context}.")
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status #{code} for #{context}. Body: #{body}")
        Logger.debug("Failed line: #{line}")
      {:error, reason} ->
        Logger.error("Failed to send log for #{context}: #{inspect(reason)}")
        Logger.debug("Failed line: #{line}")
    end
  end

  defp escape_tag(tag) when is_binary(tag), do: String.replace(tag, ~r/[\s,=]/, "_")
  defp escape_tag(tag), do: tag |> to_string() |> escape_tag()

  defp escape_field(field) when is_binary(field) do
    field
    |> String.replace(~s("), ~s(\\"))
    |> String.replace("\n", "\\n")
  end
end
