import Config

config :logger,
  backends: [:console]

config :logger, :console,
  path: "log/simulation.log",
  level: :info,
  format: {Beamulacrum.LoggerFormatter, :format},
  metadata: [:module, :function, :line, :tick, :actor, :pid]
