defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{role: Beamulator.Roles.Collector, name: "Collector", amt: 100, config: %{}},
      %{role: Beamulator.Roles.Sensor, name: "Sensor", amt: 3000, config: %{}}
    ]
  end
end
