import Config

config :logger,
  backends: [:console]
  # backends: [:console, {LoggerFileBackend, :file_logger}]

# config :logger, :file_logger,
#   path: "log/simulation.log",
#   level: :info,
#   format: {Beamulacrum.LoggerFormatter, :format},
#   metadata: [:tick]
