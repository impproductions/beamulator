import Config

config :logger,
  backends: [:console]

config :logger, :console,
  level: :info,
  format: {Beamulator.LoggerFormatter, :format},
  metadata: [:module, :function, :line, :actor, :pid, :simulation_time_ms]
