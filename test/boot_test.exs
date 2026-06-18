defmodule Beamulator.BootTest do
  use ExUnit.Case, async: false

  test "begin_on_start: false leaves the actor supervisor empty until start_actors/0 is called" do
    expected_total =
      Beamulator.ActorsConfig.actors()
      |> Enum.map(& &1.amt)
      |> Enum.sum()

    initial_children = DynamicSupervisor.which_children(Beamulator.SupervisorActors)

    if initial_children == [] do
      assert :ok = Beamulator.start_actors()
      children = DynamicSupervisor.which_children(Beamulator.SupervisorActors)
      assert length(children) == expected_total
    else
      assert length(initial_children) == expected_total
    end
  end
end
