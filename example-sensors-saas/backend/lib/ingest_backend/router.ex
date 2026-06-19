defmodule IngestBackend.Router do
  use Plug.Router
  require Logger

  alias IngestBackend.{Chaos, ILP, QuestDBWriter}

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  get "/healthz" do
    send_resp(conn, 200, "ok")
  end

  post "/ingest" do
    cond do
      Chaos.should_drop?() ->
        send_resp(conn, 503, ~s({"error":"chaos-injected outage"}))

      not valid_payload?(conn.body_params) ->
        send_resp(conn, 400, ~s({"error":"invalid payload"}))

      true ->
        %{"collector_id" => cid, "readings" => readings} = conn.body_params
        table = Application.fetch_env!(:ingest_backend, :table_name)
        iolist = ILP.encode(table, cid, readings)

        case QuestDBWriter.write(iolist) do
          :ok ->
            send_resp(conn, 200, Jason.encode!(%{ok: true, written: length(readings)}))

          {:error, reason} ->
            Logger.error("ingest write failed: #{inspect(reason)}")
            send_resp(conn, 502, Jason.encode!(%{error: "questdb write failed"}))
        end
    end
  end

  post "/admin/chaos" do
    rate = Map.get(conn.body_params, "error_rate", 0.0)
    duration = Map.get(conn.body_params, "duration_ms", 30_000)

    if is_number(rate) and rate >= 0 and rate <= 1 and is_integer(duration) and duration >= 0 do
      Chaos.set(rate * 1.0, duration)
      send_resp(conn, 200, Jason.encode!(%{ok: true, error_rate: rate, duration_ms: duration}))
    else
      send_resp(conn, 400, Jason.encode!(%{error: "expected error_rate (0..1) and duration_ms"}))
    end
  end

  get "/admin/chaos" do
    send_resp(conn, 200, Jason.encode!(Chaos.status()))
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp valid_payload?(%{"collector_id" => cid, "readings" => readings})
       when is_binary(cid) and is_list(readings) do
    Enum.all?(readings, &valid_reading?/1)
  end

  defp valid_payload?(_), do: false

  defp valid_reading?(%{"sensor_id" => sid, "metric" => m, "value" => v, "ts_ms" => ts})
       when is_binary(m) and is_number(v) and is_integer(ts) and ts > 0 and
              (is_integer(sid) or is_binary(sid)),
       do: true

  defp valid_reading?(_), do: false
end
