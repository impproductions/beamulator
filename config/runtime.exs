import Config

config :beamulacrum, Beamulacrum.Simulation,
  actors: [
    %{module: MyApp.BehaviorA, count: 10, initial_state: %{foo: 1}},
    %{module: MyApp.BehaviorB, count: 5, initial_state: %{bar: 2}}
  ]
