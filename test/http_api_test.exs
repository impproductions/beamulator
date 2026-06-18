defmodule Beamulator.HttpApiTest do
  use ExUnit.Case, async: false
  use Plug.Test
  alias Beamulator.Sinks.Memory

  defmodule Probe do
    alias Beamulator.Actions
    alias Beamulator.Lab.Duration, as: D
    use Beamulator.Behavior

    @impl true
    def default_tags(), do: MapSet.new()

    @impl true
    def default_state(), do: %{ticks: 0}

    @impl true
    def act(%{actor_state: state} = actor_data) do
      execute(actor_data, &Actions.send_collected_metrics/1, [[state.ticks]])
      {:ok, D.new(s: 10), %{actor_data | actor_state: %{state | ticks: state.ticks + 1}}}
    end
  end

  setup do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Beamulator.SupervisorActors) do
      if is_pid(pid), do: DynamicSupervisor.terminate_child(Beamulator.SupervisorActors, pid)
    end

    wait_until_registry_empty()

    Memory.reset()

    {:ok, pid} = Beamulator.SupervisorActors.create_actor("HttpProbe 1", Probe, %{})
    GenServer.call(pid, :state, 5_000)
    state = GenServer.call(pid, :state)
    {:ok, serial_id: state.serial_id}
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

  defp call(method, path) do
    conn(method, path) |> Beamulator.HttpRouter.call(Beamulator.HttpRouter.init([]))
  end

  defp json_body(conn) do
    assert conn.resp_body
    Jason.decode!(conn.resp_body)
  end

  test "GET /healthz returns 200 ok" do
    conn = call(:get, "/healthz")
    assert conn.status == 200
    assert json_body(conn) == %{"ok" => true}
  end

  test "GET /api/stats returns dashboard stats" do
    conn = call(:get, "/api/stats")
    assert conn.status == 200
    body = json_body(conn)
    assert Map.has_key?(body, "actions_total")
    assert Map.has_key?(body, "actions_successful")
  end

  test "GET /api/actors returns the actor list" do
    conn = call(:get, "/api/actors")
    assert conn.status == 200
    body = json_body(conn)
    assert %{"actors" => [%{"name" => "HttpProbe 1"}]} = body
  end

  test "GET /api/actors/:serial_id returns the actor detail", %{serial_id: serial_id} do
    conn = call(:get, "/api/actors/#{serial_id}")
    assert conn.status == 200
    body = json_body(conn)
    assert body["name"] == "HttpProbe 1"
    assert body["serial_id"] == serial_id
  end

  test "GET /api/actors/:serial_id returns 404 for an unknown id" do
    conn = call(:get, "/api/actors/999999")
    assert conn.status == 404
  end

  test "GET /api/actors/:serial_id returns 400 for a non-integer id" do
    conn = call(:get, "/api/actors/abc")
    assert conn.status == 400
  end

  test "GET /api/behaviors groups actors by behavior" do
    conn = call(:get, "/api/behaviors")
    assert conn.status == 200
    body = json_body(conn)
    assert [%{"name" => name, "count" => 1, "actors" => ["HttpProbe 1"]}] = body["behaviors"]
    assert name =~ "Probe"
  end

  test "GET /api/complaints returns an empty list" do
    conn = call(:get, "/api/complaints")
    assert conn.status == 200
    assert json_body(conn) == %{"complaints" => []}
  end
end
