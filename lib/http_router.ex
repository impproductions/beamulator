defmodule Beamulator.HttpRouter do
  use Plug.Router
  require Logger

  plug(Plug.Static,
    at: "/static",
    from: {:beamulator, "priv/static"}
  )

  plug(:match)
  plug(:dispatch)

  match "/static" do
    conn
    |> Plug.Conn.put_resp_header("location", "/static/index.html")
    |> send_resp(302, "Redirecting")
  end

  match "/" do
    conn
    |> Plug.Conn.put_resp_header("location", "/static/index.html")
    |> send_resp(302, "Redirecting")
  end

  get "/healthz" do
    json(conn, 200, %{ok: true})
  end

  get "/api/stats" do
    json(conn, 200, Beamulator.RuntimeInspector.stats())
  end

  get "/api/actors" do
    json(conn, 200, %{actors: Beamulator.RuntimeInspector.actors()})
  end

  get "/api/actors/:serial_id" do
    case Integer.parse(serial_id) do
      {sid, ""} ->
        case Beamulator.RuntimeInspector.actor(sid) do
          {:ok, detail} -> json(conn, 200, detail)
          {:error, _} -> json(conn, 404, %{error: "actor not found"})
        end

      _ ->
        json(conn, 400, %{error: "serial_id must be an integer"})
    end
  end

  get "/api/roles" do
    json(conn, 200, %{roles: Beamulator.RuntimeInspector.roles()})
  end

  get "/api/complaints" do
    json(conn, 200, %{complaints: Beamulator.RuntimeInspector.complaints()})
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  def child_spec(_opts) do
    dispatch = [
      {:_,
       [
         {"/ws", Beamulator.Dashboard.WebSocketHandler, []},
         {"/[...]", Plug.Cowboy.Handler, {__MODULE__, []}}
       ]}
    ]

    Plug.Cowboy.child_spec(
      scheme: :http,
      plug: __MODULE__,
      options: [
        port: Application.get_env(:beamulator, :http_port, 4000),
        dispatch: dispatch
      ]
    )
  end
end
