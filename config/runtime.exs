import Config

config :beamulacrum,
  enable_action_logger: true,
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
    %{behavior: Beamulacrum.Behaviors.Organizer, name: "Organizer", amt: 1, config: %{}},
    %{behavior: Beamulacrum.Behaviors.Procrastinator, name: "Procrastinator", amt: 100, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.BigSpender, name: "Big Spender", amt: 2, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.CompulsiveBrowser, name: "Compulsive browser", amt: 10, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.Scammer, name: "Scammer", amt: 1, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.Onboarder, name: "Onboarder", amt: 1, config: %{}},
    # %{behavior: Beamulacrum.Behaviors.Scanner, name: "Scanner", amt: 1, config: %{}}
  ]
