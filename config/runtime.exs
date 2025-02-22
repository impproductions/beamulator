import Config

config :beamulacrum,
  start_action_logger: true,
  questdb: %{
    url: "http://localhost",
    port: 9000
  },
  simulation: [
    random_seed: 1,
    tick_interval_ms: 10,
    tick_to_seconds: 1
  ],
  actors: [
    %{behavior: Beamulacrum.Behaviors.BigSpender, name: "Big Spender", amt: 1, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.CompulsiveBrowser, name: "Compulsive browser", amt: 1, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.Scammer, name: "Scammer", amt: 1, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.Onboarder, name: "Onboarder", amt: 1, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.Scanner, name: "Scanner", amt: 1, config: %{}}
  ]
