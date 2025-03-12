import Config

config :beamulator,
  enable_action_logger: false,
  questdb: %{
    url: "http://localhost",
    port: 9000,
    flush_batch_size: 1000,
    flush_interval_ms: 1000
  },
  simulation: [
    random_seed: 1,
    begin_on_start: true,
    time_speed_multiplier: 50
  ]
