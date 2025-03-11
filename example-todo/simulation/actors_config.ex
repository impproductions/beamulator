defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.Organizer, name: "Organizer", amt: 1, config: %{}},
      %{behavior: Beamulator.Behaviors.Procrastinator, name: "Procrastinator", amt: 30, config: %{}}
    ]
  end
end
