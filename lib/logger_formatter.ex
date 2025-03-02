defmodule Beamulator.LoggerFormatter do
  def format(level, message, timestamp, metadata) do
    time = format_timestamp(timestamp)
    duration = as_duration_human(Keyword.get(metadata, :simulation_time_ms, nil))
    actor = Keyword.get(metadata, :actor, nil)
    pid = Keyword.get(metadata, :pid, nil)

    "|#{time}|#{level}|" <>
      if(duration != nil && actor != nil,
        do: " (#{duration}|#{actor}|#{pid})",
        else: ""
      ) <>
      " #{message}\n"
  end

  defp format_timestamp({{year, month, day}, {hour, min, sec, _}}) do
    "#{year}-#{pad(month)}-#{pad(day)} #{pad(hour)}:#{pad(min)}:#{pad(sec)}"
  end

  defp as_duration_human(simulation_time_ms) when is_integer(simulation_time_ms) do
    Beamulator.Tools.Time.as_duration_human(simulation_time_ms, :shorten)
  end

  defp as_duration_human(_), do: nil

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: "#{num}"
end
