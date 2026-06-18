defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{role: Beamulator.Roles.TodoUser, name: "Todo User", amt: 100, config: %{}}
    ]
  end
end
