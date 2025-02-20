import Config

config :beamulacrum,
  simulation: [
    random_seed: 1,
    tick_interval_ms: 1000
  ],
  actors: [
    %{behavior: Beamulacrum.Behaviors.BigSpender, name: "Big Spender", amt: 2, config: %{}},
    %{behavior: Beamulacrum.Behaviors.CompulsiveBrowser, name: "Compulsive browser", amt: 4, config: %{}},
    %{behavior: Beamulacrum.Behaviors.Scammer, name: "Scammer", amt: 1, config: %{}},
  ]
