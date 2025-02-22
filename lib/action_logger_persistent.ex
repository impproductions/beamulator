defmodule ActionLoggerPersistent do
  alias Beamulacrum.Tools
  alias Beamulacrum.Ticker
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # TODO: test connection and create tables
    # case connect_to_quest() do
    #   :ok ->
    #     IO.puts("Connected to QuestDB")
    #     {:ok, %{}}

    #   {:error, reason} ->
    #     IO.puts("Failed to connect to Quest: #{inspect(reason)}")
    #     {:stop, reason}
    # end

    {:ok, %{}}
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

    # Destructure event data
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

    tick_interval = Tools.Time.tick_interval_ms()

    # Construct the InfluxDB line protocol string
    line =
      "action_log,behavior=#{escape_tag(behavior)},name=#{escape_tag(name)},action=#{escape_tag(action_as_string)} " <>
        "args=\"#{args_as_string}\",result=\"#{result_as_string}\",tick_number=#{tick_number},tick_interval=#{tick_interval},start_time_unix=\"#{escape_field(DateTime.to_iso8601(start_time))}\" " <>
        "#{timestamp}"

    url = "http://localhost:9000/write"
    headers = [{"Content-Type", "text/plain"}]

    case HTTPoison.post(url, line, headers) do
      {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
        nil
        IO.puts("[ActionLogger] Log successfully sent to QuestDB: " <> line)

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        IO.puts("[ActionLogger] QuestDB returned status code #{code}. Body: #{body}")

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
