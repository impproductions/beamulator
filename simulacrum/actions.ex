defmodule Beamulacrum.Actions do
  @moduledoc "User-defined actions."

  require Logger

  def move(%{name: name, dx: dx, dy: dy}) do
    IO.puts("Actor #{name} moving by (#{dx}, #{dy})")
    Logger.info("Actor #{name} moving by (#{dx}, #{dy})")

    {:ok, nil}
  end

  def attack(%{target: target}) do
    IO.puts("Attacking target: #{target}")
    Logger.info("Attacking target: #{target}")
    {:ok, nil}
  end

  def wait(_args) do
    IO.puts("Waiting...")
    Logger.info("Waiting...")
    {:ok, nil}
  end
end
