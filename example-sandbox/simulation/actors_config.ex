defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{role: Beamulator.Roles.Collector, name: "Collector", amt: 50, config: %{}},
      %{role: Beamulator.Roles.Sensor, name: "Sensor", amt: 2000, config: %{}}
    ]
  end
end
