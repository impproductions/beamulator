defmodule Beamulator.Actions do
  use SourceInjector
  require Logger

  def do_foo(metric) do
    Logger.info("Doing foo with metric: #{metric}")
    {:ok, %{}}
  end

  def do_bar(foos) do
    Logger.info("Collected: #{inspect(foos)}")
    {:ok, %{}}
  end
end
