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

  match _ do
    send_resp(conn, 404, "Not Found")
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
