defmodule IngestBackend.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.fetch_env!(:ingest_backend, :http_port)
    Logger.info("Starting IngestBackend on port #{port}")

    children = [
      IngestBackend.Chaos,
      IngestBackend.QuestDBWriter,
      {Plug.Cowboy, scheme: :http, plug: IngestBackend.Router, options: [port: port]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: IngestBackend.Supervisor)
  end
end
