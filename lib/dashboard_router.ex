defmodule Beamulator.Dashboard.Router do
  require Logger
  use Plug.Router

  # Serve files from beamulator/priv/static.

  plug Plug.Static,
    at: "/static",
    from: {:beamulator, "priv/static"}
  plug :match
  plug :dispatch

  match "/static" do
    # redirect to static index.html
    conn
    |> Plug.Conn.resp(302, "Redirecting")
    |> Plug.Conn.put_resp_header("location", "/static/index.html")
    |> Plug.Conn.send_resp()
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end

defmodule Beamulator.Dashboard.StaticServer do
  def start_link(_opts) do
    Plug.Cowboy.http(Beamulator.Dashboard.Router, [], port: 4000)
  end
end
