defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{role: Beamulator.Roles.Organizer, name: "Organizer", amt: 1, config: %{}},
      %{role: Beamulator.Roles.Procrastinator, name: "Procrastinator", amt: 30, config: %{}}
    ]
  end
end
