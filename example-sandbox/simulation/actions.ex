defmodule Beamulacrum.Actions do
  use SourceInjector
  require Logger

  def foo() do
    Logger.info("foo")
    {:ok, "foo"}
  end

end
