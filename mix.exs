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
      applications: [:logger, :gen_stage, :http2, :ssl]
    ]
  end

  defp deps do
    [
      # {:hpack, "~> 1.0.0"},
      {:http2, github: "kiennt/http2"},
      {:gen_stage, "~> 0.5"},
      {:gen_state_machine, "~> 1.0.2"},
      {:hackney, path: "../hackney"},
      {:connection, "~> 1.0.4"},
      {:certifi, "~> 0.4.0"}
    ]
  end
end

# bad PUSH_PROMISE payload:
# <<0, 0, 0, 2, 63, 225, 31, 130, 135, 4, 144, 97, 9, 245, 65, 81, 57, 74, 148, 48, 130, 88, 82, 212, 185, 16, 143, 65, 136, 170, 105, 210, 154, 196, 185, 236, 155, 122, 136, 218, 110, 229, 177, 128, 46, 5, 195>>
