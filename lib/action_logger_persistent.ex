defmodule Beamulator.ActionLoggerPersistent do
  alias Beamulator.Tools
  alias Beamulator.Clock
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    questdb_config = Application.get_env(:beamulator, :questdb)

    port = questdb_config[:port]

    url = "#{questdb_config[:url]}:#{port}"

    case test_connection(url) do
      :ok ->
        create_table(url)
        {:ok, %{}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp test_connection(url) do
    Logger.debug("Testing connection to QuestDB at #{url}")

    uri =
      (url <> "/exec")
      |> URI.new!()
      |> URI.append_query(URI.encode_query(exec: "SELECT 1"))
      |> URI.to_string()

    case HTTPoison.get(uri, [
           {"Content-Type", "application/json"},
           {"Accept", "application/json"}
         ]) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Successfully connected to QuestDB.")
        :ok

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status code #{code}. Body: #{body}")
        {:error, body}

      {:error, reason} ->
        Logger.error("Failed to connect to QuestDB: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_table(url) do
    ddl_log = """
    CREATE TABLE IF NOT EXISTS action_log (
      timestamp TIMESTAMP,
      behavior SYMBOL,
      name STRING,
      action STRING,
      args STRING,
      result STRING,
      tick_number DOUBLE,
      tick_interval DOUBLE,
      start_time TIMESTAMP
    ) TIMESTAMP(timestamp)
    PARTITION BY DAY
    WAL
    """

    ddl_metadata = """
    CREATE TABLE IF NOT EXISTS run_metadata (
      timestamp TIMESTAMP,
      run_id STRING,
      actions_file STRING,
      random_seed INT
    ) TIMESTAMP(timestamp)
    WAL
    """

    ddl_complaints = """
    CREATE TABLE IF NOT EXISTS complaints_log (
      timestamp TIMESTAMP,
      behavior SYMBOL,
      actor STRING,
      message STRING,
      severity SYMBOL,
      action STRING,
      args STRING,
      result STRING,
      checker STRING,
      start_time TIMESTAMP,
      run_id STRING
    ) TIMESTAMP(timestamp)
    PARTITION BY DAY
    WAL
    """

    Logger.info("Creating log and metadata tables...")

    uri =
      (url <> "/exec")
      |> URI.new!()
      |> URI.append_query(URI.encode_query(query: ddl_log))
      |> URI.to_string()

    HTTPoison.get!(uri, [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ])

    uri =
      (url <> "/exec")
      |> URI.new!()
      |> URI.append_query(URI.encode_query(query: ddl_metadata))
      |> URI.to_string()

    HTTPoison.get!(uri, [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ])

    uri =
      (url <> "/exec")
      |> URI.new!()
      |> URI.append_query(URI.encode_query(query: ddl_complaints))
      |> URI.to_string()

    res =
      HTTPoison.get!(uri, [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ])

    Logger.info("response: #{inspect(res, pretty: true)}")

    Logger.info("Complaints table created successfully")

    Logger.info("Tables created successfully")
    fill_metadata_table()

    :ok
  end

  def fill_metadata_table() do
    run_id = Application.get_env(:beamulator, :run_uuid)
    random_seed = Application.get_env(:beamulator, :simulation)[:random_seed]

    actions_file = Beamulator.Actions.source_code() |> Base.encode64()

    url = "http://localhost:9000/write"
    headers = [{"Content-Type", "text/plain"}]

    line =
      "run_metadata,run_id=#{run_id} " <>
        "actions_file=\"#{actions_file}\",random_seed=#{random_seed} " <>
        "#{DateTime.utc_now() |> DateTime.to_unix(:nanosecond)}"

    case HTTPoison.post(url, line, headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Metadata successfully sent to QuestDB.")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status code #{code}. Body: #{body}")
        Logger.debug("Failed line: #{line}")

      {:error, reason} ->
        Logger.error("Failed to send metadata to QuestDB: #{inspect(reason)}")
        Logger.debug("Failed line: #{line}")
    end
  end

  def handle_cast(
        {:log_complaint, {behavior, actor, message, severity, action, args, actual}},
        state
      ) do
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

  def handle_cast({:log_event, {{behavior, name}, action, args, result}}, state) do
    write_log(%{
      behavior: behavior,
      name: name,
      action: action,
      args: args,
      result: result
    })

    {:noreply, state}
  end

  defp write_complaint(complaint_data) do
    %{
      behavior: behavior,
      actor: actor,
      message: message,
      severity: severity,
      action: action,
      args: args,
      actual: actual
    } = complaint_data

    action_as_string = inspect(action)
    args_as_string = Jason.encode!(args) |> escape_field()
    checker_code = actual.checker |> escape_field()

    actual_as_string =
      Jason.encode!(%{
        status: actual.status,
        result: actual.result
      })
      |> escape_field()

    severity_as_string = inspect(severity)

    tick_number = Clock.get_tick_number()
    start_time = Clock.get_start_time()
    tick_as_duration = tick_number * Tools.Time.tick_interval_ms() * 10_000
    timestamp = (start_time |> DateTime.to_unix(:nanosecond)) + tick_as_duration
    start_timestamp = DateTime.to_unix(start_time, :microsecond)
    run_id = Application.get_env(:beamulator, :run_uuid)

    line =
      "complaints_log,behavior=#{escape_tag(behavior)},actor=#{escape_tag(actor)},severity=#{escape_tag(severity_as_string)} " <>
        "message=\"#{message}\",action=\"#{escape_field(action_as_string)}\",args=\"#{args_as_string}\",result=\"#{actual_as_string}\",checker=\"#{checker_code}\",start_time=#{start_timestamp}i,run_id=\"#{run_id}\" " <>
        "#{timestamp}"

    url = "http://localhost:9000/write"
    headers = [{"Content-Type", "text/plain"}]

    case HTTPoison.post(url, line, headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Successfully logged complaint by #{actor}.")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status code #{code}. Body: #{body}")
        Logger.debug("Failed line: #{line}")

      {:error, reason} ->
        Logger.error("Failed to send complaint to QuestDB: #{inspect(reason)}")
        Logger.debug("Failed line: #{line}")
    end
  end

  defp write_log(event_data) do
    %{
      behavior: behavior,
      name: name,
      action: action,
      args: args,
      result: result
    } = event_data

    action_as_string = inspect(action)
    args_as_string = Jason.encode!(args) |> escape_field()
    {status, content} = result
    result_as_string = Jason.encode!(%{status: status, content: content}) |> escape_field()

    tick_number = Clock.get_tick_number()
    start_time = Clock.get_start_time()
    tick_as_duration = tick_number * Tools.Time.tick_interval_ms() * 10_000
    timestamp = (start_time |> DateTime.to_unix(:nanosecond)) + tick_as_duration
    start_timestamp = DateTime.to_unix(start_time, :microsecond)
    run_id = Application.get_env(:beamulator, :run_uuid)

    tick_interval = Tools.Time.tick_interval_ms()

    line =
      "action_log,behavior=#{escape_tag(behavior)},name=#{escape_tag(name)},action=#{escape_tag(action_as_string)} " <>
        "args=\"#{args_as_string}\",result=\"#{result_as_string}\",tick_number=#{tick_number},tick_interval=#{tick_interval},start_time=#{start_timestamp}i,run_id=\"#{run_id}\" " <>
        "#{timestamp}"

    url = "http://localhost:9000/write"
    headers = [{"Content-Type", "text/plain"}]

    case HTTPoison.post(url, line, headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        Logger.info("Successfully logged action #{action_as_string} by #{name}.")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("QuestDB returned status code #{code}. Body: #{body}")
        Logger.debug("Failed line: #{line}")

      {:error, reason} ->
        Logger.error("Failed to send log to QuestDB: #{inspect(reason)}")
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

  defp escape_elixir_code(string) do
    escaped =
      string
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")

    "\"#{escaped}\""
  end
end
