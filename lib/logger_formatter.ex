defmodule Beamulacrum.LoggerFormatter do
  def format(_, message, timestamp, metadata) do
    tick = Keyword.get(metadata, :tick, 0) |> as_duration()
    time = format_timestamp(timestamp)

    "[#{time}] [#{tick}] #{message}\n"
  end

  defp format_timestamp({{year, month, day}, {hour, min, sec, _}}) do
    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(min)}:#{pad(sec)}"
  end

  defp as_duration(tick) when is_integer(tick) do
    Beamulacrum.Tools.Time.as_duration(tick, :shorten)
  end

  defp as_duration(_), do: "N/A"

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: "#{num}"
end
