defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Collector, name: "Collector", amt: 10, config: %{}},
      %{behavior: Beamulator.Behaviors.Fooizer, name: "Fooizer", amt: 300, config: %{}}
    ]
  end
end
