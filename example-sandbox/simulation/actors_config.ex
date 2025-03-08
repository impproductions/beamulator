defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Fooizer, name: "Fooizer", amt: 1, config: %{}}
    ]
  end
end
