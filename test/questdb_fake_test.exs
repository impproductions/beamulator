defmodule Beamulator.QuestDBFakeTest do
  use ExUnit.Case, async: false
  alias Beamulator.Clients.QuestDBFake
  alias Beamulator.ActionLogger

  setup do
    start_supervised!(QuestDBFake)
    start_supervised!({ActionLogger, [client: QuestDBFake]})
    :ok
  end

  test "events cast to ActionLogger flush as ILP lines to the fake" do
    GenServer.cast(
      ActionLogger,
      {:log_event, {{Beamulator.Behaviors.Ping, "Ping 1"}, :action_a, [1, 2], {:ok, %{}}, true}}
    )

    send(ActionLogger, :flush)
    Process.sleep(50)

    lines = QuestDBFake.posted_lines()
    assert Enum.any?(lines, fn line -> String.contains?(line, "action_log") end)
    assert Enum.any?(lines, fn line -> String.contains?(line, "Ping_1") end)
  end

  test "complaints cast to ActionLogger flush as ILP lines to the fake" do
    GenServer.cast(
      ActionLogger,
      {:log_complaint,
       {Beamulator.Behaviors.Ping, "Ping 1", "violation", :urgent, :action_a, [],
        %{trigger: "t", status: :ok, result: %{}}}}
    )

    send(ActionLogger, :flush)
    Process.sleep(50)

    lines = QuestDBFake.posted_lines()
    assert Enum.any?(lines, fn line -> String.contains?(line, "complaints_log") end)
    assert Enum.any?(lines, fn line -> String.contains?(line, "violation") end)
  end
end
