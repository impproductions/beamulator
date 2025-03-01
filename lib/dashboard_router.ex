defmodule Beamulator.Endpoint do
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

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def start_link(port \\ 4000) do
    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/ws", Beamulator.WebSocketHandler, []},
           {"/[...]", Plug.Cowboy.Handler, {__MODULE__, []}}
         ]}
      ])

    cowboy_opts = %{env: %{dispatch: dispatch}}
    :cowboy.start_clear(:http_listener, [{:port, port}], cowboy_opts)
  end
end

defmodule Beamulator.Dashboard.StaticServer do
  def start_link(_opts) do
    Beamulator.Endpoint.start_link(4000)
  end
end
