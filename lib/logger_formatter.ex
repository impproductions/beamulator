defmodule Beamulator.LoggerFormatter do
  def format(level, message, timestamp, metadata) do
    time = format_timestamp(timestamp)
    tick = as_duration_human(Keyword.get(metadata, :tick, nil))
    actor = Keyword.get(metadata, :actor, nil)
    pid = Keyword.get(metadata, :pid, nil)

    "|#{time}|#{level}|" <>
      if(tick != nil && actor != nil,
        do: " (#{tick}|#{actor}|#{pid})",
        else: ""
      ) <>
      " #{message}\n"
  end

  defp format_timestamp({{year, month, day}, {hour, min, sec, _}}) do
    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(min)}:#{pad(sec)}"
  end

  defp as_duration_human(tick) when is_integer(tick) do
    Beamulator.Tools.Time.as_duration_human(tick, :shorten)
  end

  defp as_duration_human(_), do: nil

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: "#{num}"
end
