import Config

config :logger,
  backends: [:console]

config :logger, :console,
  path: "log/simulation.log",
  level: :info,
  format: {Beamulator.LoggerFormatter, :format},
  metadata: [:module, :function, :line, :actor, :pid, :simulation_time_ms]
