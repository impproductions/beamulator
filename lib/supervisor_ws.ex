defmodule Beamulator.SupervisorWebsocket do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/ws", Beamulator.Dashboard.WebSocketHandler, []}
         ]}
      ])

    cowboy_opts = %{env: %{dispatch: dispatch}}

    children = [
      %{
        id: :cowboy_listener,
        start: {:cowboy, :start_clear, [:http_listener, [{:port, 4000}], cowboy_opts]},
        type: :worker,
        restart: :permanent,
        shutdown: 5000
      },
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
