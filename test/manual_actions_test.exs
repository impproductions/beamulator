defmodule Beamulator.ManualActionsTest do
  use ExUnit.Case, async: false
  alias Beamulator.RuntimeInspector
  alias Beamulator.Sinks.Memory
  alias Beamulator.Dashboard.WebSocketHandler

  defmodule DefaultActionsRole do
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Role

    @impl true
    def default_tags(), do: MapSet.new()
    @impl true
    def default_state(), do: %{}
    @impl true
    def act(actor_data), do: {:ok, D.new(s: 10), actor_data}
  end

  defmodule ExposeActionsRole do
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Role

    expose_actions [
      :send_collected_metrics,
      {:send_collected_metrics, default_args: [[["custom"]]]}
    ]

    @impl true
    def default_tags(), do: MapSet.new()
    @impl true
    def default_state(), do: %{}
    @impl true
    def act(actor_data), do: {:ok, D.new(s: 10), actor_data}
  end

  defmodule EmptyExposeRole do
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Role

    expose_actions []

    @impl true
    def default_tags(), do: MapSet.new()
    @impl true
    def default_state(), do: %{}
    @impl true
    def act(actor_data), do: {:ok, D.new(s: 10), actor_data}
  end

  defmodule CuratedActionsRole do
    alias Beamulator.Actions
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Role

    @impl true
    def default_tags(), do: MapSet.new()
    @impl true
    def default_state(), do: %{}
    @impl true
    def act(actor_data), do: {:ok, D.new(s: 10), actor_data}

    @impl true
    def actions() do
      [
        %{
          name: "send_metrics",
          function: &Actions.send_collected_metrics/1,
          default_args: [["payload"]]
        }
      ]
    end
  end

  setup do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Beamulator.SupervisorActors) do
      if is_pid(pid), do: DynamicSupervisor.terminate_child(Beamulator.SupervisorActors, pid)
    end

    wait_until_registry_empty()
    Memory.reset()
    :ok
  end

  defp wait_until_registry_empty(deadline_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + deadline_ms

    wait = fn loop ->
      if Beamulator.Lab.Actor.select_all() == [] do
        :ok
      else
        if System.monotonic_time(:millisecond) > deadline do
          raise "actor registry did not clear within #{deadline_ms}ms"
        end

        Process.sleep(10)
        loop.(loop)
      end
    end

    wait.(wait)
  end

  describe "Beamulator.Role.actions/0 default" do
    test "introspects Beamulator.Actions and exposes its public functions" do
      actions = DefaultActionsRole.actions()
      names = Enum.map(actions, & &1.name)
      assert "send_collected_metrics" in names

      entry = Enum.find(actions, &(&1.name == "send_collected_metrics"))
      assert is_function(entry.function, 1)
    end

    test "override returns the user-curated list" do
      assert [%{name: "send_metrics", default_args: [["payload"]]}] =
               CuratedActionsRole.actions()
    end

    test "expose_actions resolves arity from Beamulator.Actions" do
      [a, b] = ExposeActionsRole.actions()
      assert a.name == "send_collected_metrics"
      assert is_function(a.function, 1)
      assert a.default_args == nil

      assert b.name == "send_collected_metrics"
      assert b.default_args == [[["custom"]]]
    end

    test "expose_actions [] explicitly exposes nothing" do
      assert EmptyExposeRole.actions() == []
    end

    test "raises at runtime if an exposed action does not exist in Beamulator.Actions" do
      defmodule BadExposeRole do
        alias Beamulator.Lab.Duration, as: D
        use Beamulator.Role
        expose_actions [:does_not_exist]

        @impl true
        def default_tags(), do: MapSet.new()
        @impl true
        def default_state(), do: %{}
        @impl true
        def act(actor_data), do: {:ok, D.new(s: 10), actor_data}
      end

      assert_raise RuntimeError, ~r/no function named :does_not_exist/, fn ->
        BadExposeRole.actions()
      end
    end
  end

  describe "RuntimeInspector.actions_for/1" do
    test "accepts a module and returns JSON-safe entries (no function refs)" do
      [entry] = RuntimeInspector.actions_for(CuratedActionsRole)
      assert entry == %{name: "send_metrics", default_args: [["payload"]]}
    end

    test "accepts a string role name (with or without Elixir. prefix)" do
      assert [%{name: "send_metrics"}] = RuntimeInspector.actions_for(inspect(CuratedActionsRole))

      assert [%{name: "send_metrics"}] =
               RuntimeInspector.actions_for("Elixir." <> inspect(CuratedActionsRole))
    end

    test "returns [] for unknown role" do
      assert RuntimeInspector.actions_for("Definitely.Not.A.Module") == []
    end
  end

  describe "Lab.Actor.invoke/3" do
    test "executes the action in the actor's process and fans out a sink event" do
      {:ok, pid} =
        Beamulator.SupervisorActors.create_actor("Curated 1", CuratedActionsRole, %{})

      GenServer.call(pid, :state, 5_000)
      state = GenServer.call(pid, :state)
      Memory.reset()

      assert {:ok, {:ok, %{}}} =
               Beamulator.Lab.Actor.invoke(state.serial_id, "send_metrics", [["payload"]])

      events = Memory.events()
      assert length(events) >= 1
      [event | _] = events
      assert {CuratedActionsRole, "Curated 1"} == event.actor_id
      assert event.success == true
    end

    test "bumps action_count and broadcasts a state update" do
      {:ok, pid} =
        Beamulator.SupervisorActors.create_actor("BumpProbe", CuratedActionsRole, %{})

      GenServer.call(pid, :state, 5_000)
      before = GenServer.call(pid, :state)

      Registry.register(Beamulator.WebsocketRegistry, :connections, self())

      assert {:ok, _} =
               Beamulator.Lab.Actor.invoke(before.serial_id, "send_metrics", [["payload"]])

      assert_receive {:actor_state_update, after_state}, 500
      assert after_state.runtime_stats.action_count == before.runtime_stats.action_count + 1

      after_call = GenServer.call(pid, :state)
      assert after_call.runtime_stats.action_count == before.runtime_stats.action_count + 1
    end

    test "returns {:error, :unknown_action} for an unknown action name" do
      {:ok, pid} =
        Beamulator.SupervisorActors.create_actor("Curated 2", CuratedActionsRole, %{})

      GenServer.call(pid, :state, 5_000)
      state = GenServer.call(pid, :state)

      assert {:error, :unknown_action} =
               Beamulator.Lab.Actor.invoke(state.serial_id, "no_such_action", nil)
    end

    test "returns {:error, :actor_not_found} for an unknown serial_id" do
      assert {:error, :actor_not_found} =
               Beamulator.Lab.Actor.invoke(987_654_321, "send_metrics", nil)
    end
  end

  describe "WS handler messages" do
    test "get_actions returns the role's action list" do
      msg = Jason.encode!(%{"type" => "get_actions", "role" => inspect(CuratedActionsRole)})
      {:reply, {:text, reply}, _} = WebSocketHandler.websocket_handle({:text, msg}, %{})

      decoded = Jason.decode!(reply)
      assert decoded["type"] == "actions"
      assert decoded["role"] == inspect(CuratedActionsRole)
      assert [%{"name" => "send_metrics"}] = decoded["actions"]
    end

    test "invoke_action runs the action and replies with success" do
      {:ok, pid} =
        Beamulator.SupervisorActors.create_actor("Curated 3", CuratedActionsRole, %{})

      GenServer.call(pid, :state, 5_000)
      state = GenServer.call(pid, :state)

      msg =
        Jason.encode!(%{
          "type" => "invoke_action",
          "serial_id" => state.serial_id,
          "action" => "send_metrics",
          "args" => [["payload"]]
        })

      {:reply, {:text, reply}, _} = WebSocketHandler.websocket_handle({:text, msg}, %{})

      decoded = Jason.decode!(reply)
      assert decoded["type"] == "invoke_result"
      assert decoded["serial_id"] == state.serial_id
      assert decoded["action"] == "send_metrics"
      assert decoded["success"] == true
    end

    test "invoke_action with unknown action replies success=false" do
      {:ok, pid} =
        Beamulator.SupervisorActors.create_actor("Curated 4", CuratedActionsRole, %{})

      GenServer.call(pid, :state, 5_000)
      state = GenServer.call(pid, :state)

      msg =
        Jason.encode!(%{
          "type" => "invoke_action",
          "serial_id" => state.serial_id,
          "action" => "missing",
          "args" => nil
        })

      {:reply, {:text, reply}, _} = WebSocketHandler.websocket_handle({:text, msg}, %{})

      decoded = Jason.decode!(reply)
      assert decoded["success"] == false
      assert decoded["result"]["error"] =~ "unknown_action"
    end
  end
end
