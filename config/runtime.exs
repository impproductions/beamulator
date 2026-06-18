import Config

config :beamulator,
  enable_action_logger: false,
  start_memory_sink: false,
  action_sinks: [Beamulator.Sinks.DashboardStats],
  questdb_client: Beamulator.Clients.QuestDBHttp,
  runtime_inspector: Beamulator.RuntimeInspectors.InProcess,
  questdb: %{
    url: "http://localhost",
    port: 9000,
    flush_batch_size: 1000,
    flush_interval_ms: 1000
  },
  simulation: [
    random_seed: 1,
    begin_on_start: true,
    deterministic_boot: false,
    clock_mode: :auto,
    time_speed_multiplier: 200
  ]

if config_env() == :test do
  config :beamulator,
    enable_action_logger: false,
    start_memory_sink: true,
    action_sinks: [Beamulator.Sinks.DashboardStats, Beamulator.Sinks.Memory],
    simulation: [
      random_seed: 1,
      begin_on_start: false,
      deterministic_boot: true,
      clock_mode: :manual,
      time_speed_multiplier: 200
    ]
end
