defmodule ActionLoggerPersistent do
  alias Beamulacrum.Tools
  alias Beamulacrum.Ticker
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    questdb_config = Application.get_env(:beamulacrum, :questdb)

    port = questdb_config[:port]

    url = "#{questdb_config[:url]}:#{port}"

    case test_connection(url) do
      :ok ->
        IO.puts("Connected to QuestDB")
        create_table(url)
        {:ok, %{}}

      {:error, reason} ->
        IO.puts("Failed to connect to Quest: #{inspect(reason)}")
        {:stop, reason}
    end

    {:ok, %{}}
  end

  defp test_connection(url) do
    IO.puts("[ActionLogger] Testing connection to QuestDB at #{url}")

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
        IO.puts("[ActionLogger] Successfully connected to QuestDB")
        :ok

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        IO.puts("[ActionLogger] QuestDB returned status code #{code}. Body: #{body}")
        {:error, body}

      {:error, reason} ->
        IO.puts("[ActionLogger] Failed to connect to QuestDB: #{inspect(reason)}")
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

    IO.puts("[ActionLogger] Creating log table...")

    uri =
      (url <> "/exec")
      |> URI.new!()
      |> URI.append_query(URI.encode_query(query: ddl_log))
      |> URI.to_string()

    HTTPoison.get!(uri, [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ])

    IO.puts("[ActionLogger] Creating metadata table...")

    uri =
      (url <> "/exec")
      |> URI.new!()
      |> URI.append_query(URI.encode_query(query: ddl_metadata))
      |> URI.to_string()

    HTTPoison.get!(uri, [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ])

    IO.puts("[ActionLogger] Tables created successfully")

    IO.puts("[ActionLogger] Filling metadata table...")
    fill_metadata_table()
    :ok
  end

  def fill_metadata_table() do
    run_id = Application.get_env(:beamulacrum, :run_uuid)
    random_seed = Application.get_env(:beamulacrum, :simulation)[:random_seed]

    actions_file = File.read!("simulacrum/actions.ex") |> Base.encode64()

    url = "http://localhost:9000/write"
    headers = [{"Content-Type", "text/plain"}]

    line =
      "run_metadata,run_id=#{run_id} " <>
        "actions_file=\"#{actions_file}\",random_seed=#{random_seed} " <>
        "#{DateTime.utc_now() |> DateTime.to_unix(:nanosecond)}"

    case HTTPoison.post(url, line, headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        IO.puts("[ActionLogger] Metadata successfully sent to QuestDB.")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        IO.puts("[ActionLogger] QuestDB returned status code #{code}. Body: #{body}")
        IO.puts("[ActionLogger] Failed line: #{line}")

      {:error, reason} ->
        IO.puts("[ActionLogger] Failed to send metadata to QuestDB: #{inspect(reason)}")
        IO.puts("[ActionLogger] Failed line: #{line}")
    end
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

  defp write_log(event_data) do
    IO.puts("[ActionLogger] Writing log to QuestDB")

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

    tick_number = Ticker.get_tick_number()
    start_time = Ticker.get_start_time()
    tick_as_duration = tick_number * Tools.Time.tick_interval_ms() * 10_000
    timestamp = (start_time |> DateTime.to_unix(:nanosecond)) + tick_as_duration
    start_timestamp = DateTime.to_unix(start_time, :microsecond)
    run_id = Application.get_env(:beamulacrum, :run_uuid)

    tick_interval = Tools.Time.tick_interval_ms()

    # Construct the InfluxDB line protocol string
    line =
      "action_log,behavior=#{escape_tag(behavior)},name=#{escape_tag(name)},action=#{escape_tag(action_as_string)} " <>
        "args=\"#{args_as_string}\",result=\"#{result_as_string}\",tick_number=#{tick_number},tick_interval=#{tick_interval},start_time=#{start_timestamp}i,run_id=\"#{run_id}\" " <>
        "#{timestamp}"

    url = "http://localhost:9000/write"
    headers = [{"Content-Type", "text/plain"}]

    case HTTPoison.post(url, line, headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        nil
        IO.puts("[ActionLogger] Log successfully sent to QuestDB: " <> line)

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        IO.puts("[ActionLogger] QuestDB returned status code #{code}. Body: #{body}")
        IO.puts("[ActionLogger] Failed line: #{line}")

      {:error, reason} ->
        IO.puts("[ActionLogger] Failed to send log to QuestDB: #{inspect(reason)}")
        IO.puts("[ActionLogger] Failed line: #{line}")
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
