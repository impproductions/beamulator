defmodule Beamulator.ActionLoggerTolerantTest do
  use ExUnit.Case, async: false
  alias Beamulator.Clients.QuestDBUnreachable
  alias Beamulator.ActionLogger

  test "start_link succeeds and process stays alive when the QuestDB client is unreachable" do
    pid = start_supervised!({ActionLogger, [client: QuestDBUnreachable]})

    assert Process.alive?(pid)

    GenServer.cast(
      ActionLogger,
      {:log_event, {{Beamulator.Behaviors.Ping, "Ping 1"}, :action_a, [], {:ok, %{}}, true}}
    )

    Process.sleep(20)
    assert Process.alive?(pid)
  end
end
