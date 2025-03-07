defmodule Beamulator.ActorsConfig do
  def actors() do
    [
      %{behavior: Beamulator.Behaviors.TodoUser, name: "Todo User", amt: 1, config: %{}}
    ]
  end
end
