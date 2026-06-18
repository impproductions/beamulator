# Framework Testing & Instrumentation Tracker

Branch: `init-agent-refactor`. Status: planned, not started.

## Context & philosophy

This plan came out of a Socratic back-and-forth, not an upfront spec dump. Capturing how it evolved because the *shape of the conversation* encodes what matters to the user better than a clean summary would.

- Opening ask was broad: "summarize the repo, then tell me what's blocking automated feedback." The user asked me to **restate before doing anything** — confirmation of understanding precedes execution.
- When I tried to pin "unit-test-based e2e" with a tidy definition, the user pushed back: *"Yes-ish. I don't have a clear picture but I have requirements: self-contained (no ext deps), ExUnit-based, tests logical branching of the system as a whole in a fast, predictable and easily inspectable manner."* → Requirements over rigid categories. Don't seek crisp definitions when crisp constraints will do.
- Frontend scope was trimmed twice. First: WS-level assertions fine, no browser-based testing. Then, after the plan landed: no dashboard assertions at all in blackbox — *"I only care about the simulation output and the possibility to correctly inspect the runtime state — it can be over a text-based API."*
- Items were added incrementally as the design surfaced them, not specified upfront: "external service clients should be injectable" came after the main plan; then "the runtime inspection service is itself a replaceable dependency — same API serves dashboard, CLI, tests."
- Sharp framework-vs-user-code line. Example simulations are user code that happens to live in this repo; their external HTTP clients are out of scope. The framework owns Clock, actors, registry, action execution, sinks, complaints, and the inspection interface. Tests cover the framework.
- Recurring lens: **anything the framework talks to across its boundary sits behind an Elixir behaviour with a swappable test impl.** Applies to outbound (QuestDB sink) and to inbound introspection (dashboard / CLI / tests are all consumers of one inspection interface).
- Plan format requested: short bullets, execution-ordered, current → fully instrumented. The user adds wrapper `mix` commands at the end so each layer has a single entry point.

## Batch plan format

Work proceeds in batches sized to fit one terminal page. Each batch is presented as:

- **Batch name** — one-line scope.
- **What & why** — 1–2 sentences.
- **How we check it works** — automated tests where the feature is testable, otherwise explicit manual checks.
- **Implementation** — flat list, one bullet per localized change. Each bullet is `path/to/file.ex` → domain-level description of what changes there (not a diff, but specific enough that a reader can map it to code). One file may have multiple bullets.

The user approves each batch before implementation.

## Execution plan

1. Fix existing unit tests — rename `Utils.Duration`/`Utils.Signal` references → `Lab.*`, drop the bogus `doctest Beamulator`, rename the duplicated `DurationTest` module.
2. Add `:test` config (split `config/test.exs` or branch in `runtime.exs`) — `begin_on_start: false`, `enable_action_logger: false`, deterministic `random_seed`.
3. Make `simulation_path` env-driven — read `BEAMULATOR_SIM_PATH` in `mix.exs`, fall back to current default.
4. Add `test/fixtures/simulation/` — tiny 2-role, 3-actor scenario for hermetic tests; loaded via the env var under `MIX_ENV=test`.
5. Gate startup jitter behind config — `actor.ex` and `actor_inizializer.ex` skip the `:rand.uniform` sleeps when `simulation[:deterministic_boot]` is true.
6. Decouple Clock from wall time — introduce `:auto | :manual` mode; in `:manual`, expose `Clock.set_now/1` and `Clock.advance/1`.
7. Route actor scheduling through Clock — replace direct `Process.send_after(self(), :act, …)` with a Clock-driven scheduler that, in `:manual`, fires ticks on `advance/1`.
8. Extract an `ActionSink` behaviour — `ActionExecutor` calls a configurable sink module; default fan-out to `DashboardStatsProvider` + optional `ActionLogger`.
9. Extract the framework's external-client pattern — QuestDB client (used by `ActionLogger`) goes behind a `Beamulator.Clients.QuestDB` behaviour with `QuestDBHttp` (real) and `QuestDBFake` (test) impls, resolved via config. Applies to any future first-party external integration. **Does not** apply to example-simulation HTTP clients (user code).
10. Add `MemorySink` — test sink storing `{action, args, result, sim_time}` events; exposes `events/0`, `complaints/0`, `reset/0`.
11. Route complaints through the sink — replace direct `GenServer.cast(ActionLogger, …)` so complaints are observable even with QuestDB off.
12. Extract a `RuntimeInspector` behaviour — the single API the dashboard, future CLI, and tests all consume to read live state (stats, actors, roles, individual actor state, complaints). One interface, multiple consumers.
13. Move QuestDB write URL to config — drop the `@write_url` hardcode in `action_logger.ex:9`, build from `questdb.url/port`.
14. Make `ActionLogger.init` tolerant — never `{:stop, …}` on connect failure; log, retry on interval, buffer or drop per config.
15. Add `Beamulator.TestSupport.start_simulation/1` — boots a minimal subtree (Registries, Clock in `:manual`, SupervisorActors, MemorySink) with the fixture sim, returns a handle, tears down cleanly.
16. Write the first in-process e2e — boot fixture, `Clock.advance(D.new(m: 10))`, assert on `MemorySink.events()` and `ActorRegistry` contents.
17. Add JSON read endpoints backed by `RuntimeInspector` — `GET /healthz`, `/api/stats`, `/api/actors`, `/api/actors/:serial_id`, `/api/roles`, `/api/complaints`. Refactor the dashboard WS handler to consume the same interface.
18. Add app service to `docker-compose.yml` — builds from `Dockerfile`, `depends_on` QuestDB, exposes `:4000`, env vars for sim path / logger toggle.
19. Write a blackbox smoke test — boots compose, polls `/healthz`, asserts `/api/stats` and `/api/actors` shape against the sensors fixture. No dashboard assertions; simulation output + runtime state inspected over the JSON API only.
20. Wrap in commands — `mix beam.test.unit`, `mix beam.test.e2e` (sets sim path env, runs in-process suite), `mix beam.test.blackbox` (compose up, wait-healthy, run suite, compose down), `mix beam.run.sim SIM=example-todo`.
21. Clean up dead code — remove unused `lib/supervisor_ws.ex`, fix `application.ex:53` return value.

## Findings (deferred)

- **Scheduling scales poorly under the sensors sim.** 3100 actors firing through one Clock GenServer, combined with collectors making sync `Lab.Actor.get_state!/1` calls to thousands of tagged sensors per `:act`, causes contention and 5s+ `GenServer.call` timeouts in tests. Not a framework blocker (sensors is user code, at-scale testing isn't the framework's job) and pursuing it now would derail the test-substrate work. Revisit after the blackbox layer is in place so we can measure improvements end-to-end.

## Out of scope

- Browser-based dashboard testing.
- Any dashboard assertions in blackbox tests — blackbox only cares about simulation output and runtime-state inspection over the text API.
- Example-simulation external clients (FastAPI/Go server HTTP). Users write their own roles; their service mocks are their concern. The framework's behaviour-based sink/client pattern is a template they can copy, not a contract they must adopt.
