import Config

config :beamulacrum,
  simulation: [
    tick_interval_ms: 10
  ],
  actors: [
    %{behavior: Beamulacrum.Behaviors.Wanderer, name: "Slow Wanderer", amt: 5, config: %{speed: 1}},
    %{behavior: Beamulacrum.Behaviors.Wanderer, name: "Fast Wanderer", amt: 2, config: %{speed: 10}}
  ]
