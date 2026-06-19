defmodule IngestBackend.ILP do
  @moduledoc """
  Encodes sensor readings to QuestDB InfluxDB Line Protocol.

  Symbols escape: comma, space, equals. Field strings would need quoting +
  backslash escape, but we only emit numeric fields here.
  """

  @doc """
  Encodes a batch of readings into a single ILP iolist.

    readings: [%{"sensor_id" => 1, "metric" => "temperature", "value" => 21.5, "ts_ms" => 1700000000000}]
    collector_id: "Collector-1"
    table: "sensor_reading"
  """
  def encode(table, collector_id, readings) when is_list(readings) do
    Enum.map(readings, &encode_line(table, collector_id, &1))
  end

  defp encode_line(table, collector_id, %{} = r) do
    sensor = to_string(Map.fetch!(r, "sensor_id"))
    metric = Map.fetch!(r, "metric")
    value = Map.fetch!(r, "value")
    ts_ms = Map.fetch!(r, "ts_ms")
    ts_ns = ts_ms * 1_000_000

    [
      table,
      ?,,
      "collector=",
      esc_symbol(collector_id),
      ?,,
      "sensor=",
      esc_symbol(sensor),
      ?,,
      "metric=",
      esc_symbol(metric),
      ?\s,
      "value=",
      encode_float(value),
      ?\s,
      Integer.to_string(ts_ns),
      ?\n
    ]
  end

  defp encode_float(v) when is_float(v), do: Float.to_string(v)
  defp encode_float(v) when is_integer(v), do: Integer.to_string(v) <> "i"

  defp esc_symbol(v) when is_binary(v) do
    v
    |> String.replace(",", "\\,")
    |> String.replace(" ", "\\ ")
    |> String.replace("=", "\\=")
  end

  defp esc_symbol(v), do: esc_symbol(to_string(v))
end
