defmodule Beamulator.Actions do
  use SourceInjector

  def noop(_args), do: {:ok, %{}}
end
