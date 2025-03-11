defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Collector, name: "Collector", amt: 50, config: %{}},
      %{behavior: Beamulator.Behaviors.Sensor, name: "Sensor", amt: 2000, config: %{}}
    ]
  end
end
