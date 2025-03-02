import Config

config :beamulator,
  enable_action_logger: true,
  questdb: %{
    url: "http://localhost",
    port: 9000
  },
  simulation: [
    random_seed: 1,
    begin_on_start: true,
    time_speed_multiplier: 1000
  ],
  actors: [
    # %{behavior: Beamulator.Behaviors.Fooizer, name: "Fooizer", amt: 1000, config: %{}}
    %{behavior: Beamulator.Behaviors.Organizer, name: "Organizer", amt: 1, config: %{}},
    %{behavior: Beamulator.Behaviors.Procrastinator, name: "Procrastinator", amt: 10000, config: %{}},
    # %{behavior: Beamulator.Behaviors.BigSpender, name: "Big Spender", amt: 2, config: %{}},
    # %{behavior: Beamulator.Behaviors.CompulsiveBrowser, name: "Compulsive browser", amt: 10, config: %{}},
    # %{behavior: Beamulator.Behaviors.Scammer, name: "Scammer", amt: 1, config: %{}},
    # %{behavior: Beamulator.Behaviors.Onboarder, name: "Onboarder", amt: 1, config: %{}},
    # %{behavior: Beamulator.Behaviors.Scanner, name: "Scanner", amt: 1, config: %{}}
  ]
