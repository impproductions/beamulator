defmodule Beamulator.Tools.Duration do
  @type time_unit ::
          :ms | :s | :m | :h | :d | :w

  @second 1000
  @minute 60 * @second
  @hour 60 * @minute
  @day 24 * @hour
  @week 7 * @day

  @spec new([{time_unit(), non_neg_integer()}]) :: non_neg_integer()
  def new(opts \\ []) do
    ms = Keyword.get(opts, :ms, 0)
    s = Keyword.get(opts, :s, 0)
    m = Keyword.get(opts, :m, 0)
    h = Keyword.get(opts, :h, 0)
    d = Keyword.get(opts, :d, 0)
    w = Keyword.get(opts, :w, 0)

    ms + s * @second + m * @minute + h * @hour + d * @day + w * @week
  end

  def to_string(duration) do
    {weeks, rem} = {div(duration, @week), rem(duration, @week)}
    {days, rem} = {div(rem, @day), rem(rem, @day)}
    {hours, rem} = {div(rem, @hour), rem(rem, @hour)}
    {minutes, rem} = {div(rem, @minute), rem(rem, @minute)}
    {seconds, milliseconds} = {div(rem, @second), rem(rem, @second)}

    parts = [
      {weeks, "week"},
      {days, "day"},
      {hours, "hour"},
      {minutes, "minute"},
      {seconds, "second"},
      {milliseconds, "millisecond"}
    ]

    parts
    |> Enum.filter(fn {amt, _} -> amt > 0 end)
    |> Enum.map(fn {amt, unit} ->
      plural = if amt > 1, do: "s", else: ""
      "#{amt} #{unit}#{plural}"
    end)
    |> Enum.join(", ")
  end
end
