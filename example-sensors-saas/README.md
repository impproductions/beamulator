# example-sensors-saas

End-to-end demo: an IoT-SaaS that ingests sensor readings into QuestDB,
exercised by a Beamulator simulation of collectors and sensors running at
200× real time.

The backend is a tiny Elixir service. The "SaaS UI" is **QuestDB's own
web console** at http://localhost:9100 — that's where you query the data
the simulation is producing.

## Architecture

```
  +----------+  HTTP   +-----------------+   ILP   +---------+
  | sim:     |  /ingest| sim:            |  9009   | sim:    |
  | Collector|<------->| ingest_backend  |<------->| QuestDB |
  +----------+         +-----------------+         +---------+
       ^                       ^                        ^
       |                       | /admin/chaos           | UI :9000
       |                       |                        |
  +----------+            +----------------+            |
  | sim:     |            | sim:           |   you  ----+
  | Sensor   |            | ChaosDirector  |
  +----------+            +----------------+
```

`sim:` boxes run inside the Beamulator simulator (one OS process,
hundreds of BEAM processes). `ingest_backend` and `questdb` run inside
docker-compose.

## Running

Two terminals.

**Terminal 1** — backend stack:

```bash
cd example-sensors-saas
docker compose up --build
```

Wait until you see `Connected to QuestDB ILP at questdb:9009` from the
backend container.

**Terminal 2** — simulator, from the repo root:

```bash
BEAMULATOR_SIM_PATH=example-sensors-saas/simulation iex -S mix
```

Open:

- **QuestDB UI** (the SaaS UI): http://localhost:9100
- **Simulator dashboard**: http://localhost:4000/static/index.html

> The non-standard QuestDB port (`9100` instead of `9000`) is so this stack
> can coexist with the repo-level `docker-compose.yml`, which runs its own
> QuestDB on `9000` for simulator telemetry (`action_log`, `complaints_log`).
> The two QuestDB instances are independent — SaaS data lives here, the
> simulator's own action/complaint logs live in the other one.

## What you'll see (and where)

| Where                         | What                                                                |
| ----------------------------- | ------------------------------------------------------------------- |
| Simulator dashboard           | 10 collectors + 300 sensors + 1 chaos director, ticking 200× faster |
| SaaS QuestDB (:9100) → `sensor_reading`     | A few real-seconds of wall clock = hours of simulated history |
| Simulator dashboard → complaints feed       | Live `Backend unavailable`, `Stuck sensor`, etc.              |
| Simulator QuestDB (:9000) → `complaints_log` | Same complaints, persisted (if action_logger is enabled)     |
| Backend logs (`docker logs saas-backend`)   | `CHAOS ON` lines when the chaos director flips the switch     |

## Showcase queries (paste into QuestDB UI)

Per-collector ingestion rate:

```sql
SELECT collector, count() AS readings
FROM sensor_reading
WHERE timestamp > dateadd('m', -5, now())
GROUP BY collector
ORDER BY readings DESC;
```

Average temperature per collector, 1-minute buckets:

```sql
SELECT timestamp, collector, avg(value) AS avg_temp
FROM sensor_reading
WHERE metric = 'temperature'
SAMPLE BY 1m;
```

Recent complaints (paste into the **simulator's** QuestDB on `:9000`, not
the SaaS one):

```sql
SELECT timestamp, severity, message, actor_name
FROM complaints_log
ORDER BY timestamp DESC
LIMIT 50;
```

Stuck-sensor complaints only:

```sql
SELECT timestamp, actor_name, message
FROM complaints_log
WHERE message LIKE 'Stuck sensor%'
ORDER BY timestamp DESC;
```

## Failure scenarios

Three are wired in:

1. **Stuck sensors** (~8% of the sensor population, set at boot). Emit a
   constant value. Collectors track a rolling variance window per sensor
   and fire a `Stuck sensor(s) detected: ...` complaint when the window
   has zero variance.

2. **Flaky collectors** (~10% of collectors, set at boot). Occasionally
   drop a required field from the payload. The backend returns 400; the
   collector fires `Backend rejected ingest payload`.

3. **Network partition** (cycled by `ChaosDirector`). Every ~10
   simulated minutes the director POSTs `/admin/chaos` to enable a 60%
   503 rate for ~45 simulated seconds. All collectors hitting the
   backend during that window fire `Backend unavailable (503)`.

## Manually trigger chaos

Bypass the director and force an outage:

```bash
curl -X POST http://localhost:4100/admin/chaos \
  -H 'content-type: application/json' \
  -d '{"error_rate": 1.0, "duration_ms": 15000}'
```

Status:

```bash
curl http://localhost:4100/admin/chaos
```

## Backend endpoints

| Method | Path             | Body                                            | Purpose                  |
| ------ | ---------------- | ----------------------------------------------- | ------------------------ |
| GET    | `/healthz`       | —                                               | liveness                 |
| POST   | `/ingest`        | `{collector_id, readings: [{sensor_id, metric, value, ts_ms}]}` | write batch to QuestDB   |
| POST   | `/admin/chaos`   | `{error_rate: 0..1, duration_ms: int}`          | flip the 503 injector    |
| GET    | `/admin/chaos`   | —                                               | inspect chaos state      |

## Tearing down

```bash
docker compose down -v   # -v wipes the QuestDB volume
```
