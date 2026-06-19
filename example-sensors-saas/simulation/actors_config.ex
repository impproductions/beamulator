defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{role: Beamulator.Roles.Collector, name: "Collector", amt: 10, config: %{}},
      %{role: Beamulator.Roles.Sensor, name: "Sensor", amt: 300, config: %{}},
      %{role: Beamulator.Roles.ChaosDirector, name: "ChaosDirector", amt: 1, config: %{}}
    ]
  end
end
