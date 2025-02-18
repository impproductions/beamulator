defmodule Beamulacrum.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamulacrum,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      mod: {Beamulacrum.Application, []}, # Start Beamulacrum on launch
      extra_applications: [:logger]
    ]
  end

  def escript do
    [main_module: Beamulacrum]
  end
end
