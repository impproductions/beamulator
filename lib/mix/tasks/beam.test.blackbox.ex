defmodule Mix.Tasks.Beam.Test.Blackbox do
  use Mix.Task
  @shortdoc "Boot docker-compose stack, run blackbox tests, tear down."
  @moduledoc """
  Orchestrates the blackbox test layer:

    1. `docker compose up -d --build` (builds the app image and starts QuestDB + the app)
    2. Polls `http://localhost:4000/healthz` until 200 or timeout
    3. Runs `mix test --only blackbox`
    4. `docker compose down` (always, even on failure)

  Requires Docker available on the host. Pass `BEAMULATOR_SIM_PATH` through the
  environment to build a different simulation into the image.
  """

  @health_url "http://localhost:4000/healthz"
  @default_deadline_ms 60_000

  def run(_args) do
    {_, 0} = System.cmd("docker", ["compose", "up", "-d", "--build"], into: IO.stream(:stdio, :line))

    try do
      :ok = wait_for_health(@default_deadline_ms)
      Mix.Task.run("test", ["--only", "blackbox"])
    after
      System.cmd("docker", ["compose", "down"], into: IO.stream(:stdio, :line))
    end
  end

  defp wait_for_health(deadline_ms) do
    Application.ensure_all_started(:inets)
    deadline = System.monotonic_time(:millisecond) + deadline_ms

    poll = fn loop ->
      case :httpc.request(:get, {String.to_charlist(@health_url), []}, [], []) do
        {:ok, {{_, 200, _}, _, _}} ->
          :ok

        _ ->
          if System.monotonic_time(:millisecond) > deadline do
            raise "blackbox stack did not become healthy within #{deadline_ms}ms"
          end

          Process.sleep(500)
          loop.(loop)
      end
    end

    poll.(poll)
  end
end
