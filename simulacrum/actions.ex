defmodule Beamulacrum.Actions do
  @moduledoc "User-defined actions."

  def move(%{name: name, dx: dx, dy: dy}) do
    IO.puts("Actor #{name} moving by (#{dx}, #{dy})")
    {:ok, nil}
  end

  def attack(%{target: target}) do
    IO.puts("Attacking target: #{target}")
    {:ok, nil}
  end

  def wait(_args) do
    IO.puts("Waiting...")
    {:ok, nil}
  end

  def testwrong() do
    IO.puts("This is a test")
  end
end
