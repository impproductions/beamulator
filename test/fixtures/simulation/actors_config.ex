defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{role: Beamulator.Roles.Ping, name: "Ping", amt: 2, config: %{}},
      %{role: Beamulator.Roles.Pong, name: "Pong", amt: 1, config: %{}}
    ]
  end
end
