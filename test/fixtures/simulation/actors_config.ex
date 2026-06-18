defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Ping, name: "Ping", amt: 2, config: %{}},
      %{behavior: Beamulator.Behaviors.Pong, name: "Pong", amt: 1, config: %{}}
    ]
  end
end
