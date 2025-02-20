import Config

config :beamulacrum,
  simulation: [
    random_seed: 1,
    tick_interval_ms: 100
  ],
  actors: [
    %{behavior: Beamulacrum.Behaviors.Wanderer, name: "Slow Wanderer", amt: 3, config: %{speed: 1}},
    %{behavior: Beamulacrum.Behaviors.Wanderer, name: "Fast Wanderer", amt: 2, config: %{speed: 10}}
  ]
