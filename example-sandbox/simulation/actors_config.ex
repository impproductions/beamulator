defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Collector, name: "Collector", amt: 1, config: %{}},
      %{behavior: Beamulator.Behaviors.Fooizer, name: "Fooizer", amt: 10, config: %{}}
    ]
  end
end
