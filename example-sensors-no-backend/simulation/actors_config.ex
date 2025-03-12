defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Collector, name: "Collector", amt: 100, config: %{}},
      %{behavior: Beamulator.Behaviors.Sensor, name: "Sensor", amt: 3000, config: %{}}
    ]
  end
end
