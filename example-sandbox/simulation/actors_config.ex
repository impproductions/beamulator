defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Collector, name: "Collector", amt: 100, config: %{}},
      %{behavior: Beamulator.Behaviors.Fooizer, name: "Fooizer", amt: 3000, config: %{}}
    ]
  end
end
