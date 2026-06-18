defmodule Beamulator.Blackbox.ApiTest do
  @moduledoc """
  Blackbox HTTP smoke test. Excluded from `mix test` by default. Run via
  `mix beam.test.blackbox`, which brings up the docker-compose stack first.

  These tests expect the app to be running in production mode (`begin_on_start: true`),
  so they will fail if pointed at an in-process `:test` BEAM where actors aren't
  auto-spawned.
  """
  use ExUnit.Case, async: false
  @moduletag :blackbox

  @base "http://localhost:4000"
  @health_deadline_ms (System.get_env("BEAMULATOR_BLACKBOX_HEALTH_DEADLINE_MS") || "60000")
                     |> String.to_integer()

  setup_all do
    {:ok, _} = Application.ensure_all_started(:httpoison)
    :ok = wait_for_health(@health_deadline_ms)
    :ok
  end

  defp wait_for_health(deadline_ms) do
    deadline = System.monotonic_time(:millisecond) + deadline_ms

    poll = fn loop ->
      case HTTPoison.get("#{@base}/healthz") do
        {:ok, %HTTPoison.Response{status_code: 200}} ->
          :ok

        _ ->
          if System.monotonic_time(:millisecond) > deadline do
            {:error, :timeout}
          else
            Process.sleep(500)
            loop.(loop)
          end
      end
    end

    poll.(poll)
  end

  defp get_json(path) do
    {:ok, %HTTPoison.Response{status_code: status, body: body}} = HTTPoison.get(@base <> path)
    {status, Jason.decode!(body)}
  end

  test "GET /healthz returns ok" do
    assert {200, %{"ok" => true}} = get_json("/healthz")
  end

  test "GET /api/stats has the expected keys" do
    assert {200, body} = get_json("/api/stats")
    for key <- ["actions_total", "actions_successful", "actions_failed", "actors_crashes"] do
      assert Map.has_key?(body, key), "missing #{key}"
    end
  end

  test "GET /api/actors returns the configured population" do
    assert {200, %{"actors" => actors}} = get_json("/api/actors")
    assert is_list(actors)
    assert length(actors) > 0
  end

  test "GET /api/roles lists at least one role" do
    assert {200, %{"roles" => roles}} = get_json("/api/roles")
    assert is_list(roles)
    assert length(roles) > 0
  end

  test "GET /api/complaints returns a list" do
    assert {200, %{"complaints" => complaints}} = get_json("/api/complaints")
    assert is_list(complaints)
  end
end
