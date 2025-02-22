import Config

config :logger,
  backends: [:console]

config :logger, :console,
  path: "log/simulation.log",
  level: :info,
  format: "|$time|$level| $message\n",
  metadata: [:module, :function, :line, :tick]
