defmodule River.Mixfile do
  use Mix.Project

  def project do
    [app: :river,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [
      mod: {River, []},
      applications: [:logger, :gen_stage, :hpack, :ssl]
    ]
  end

  defp deps do
    [
      {:hpack, "~> 1.0.0"},
      {:gen_stage, "~> 0.5"},
      {:gen_state_machine, "~> 1.0.2"},
      {:hackney, path: "../hackney"},
      {:certifi, "~> 0.4.0"}
    ]
  end
end
