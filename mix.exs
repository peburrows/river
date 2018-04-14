defmodule River.Mixfile do
  use Mix.Project

  def project do
    [
      app: :river,
      version: "0.0.7",
      elixir: "~> 1.5",
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {River, []},
      applications: [:logger, :ssl, :certifi]
    ]
  end

  defp deps do
    [
      {:hpack, "~> 1.0.2"},
      {:connection, "~> 1.0.4"},
      {:certifi, "~> 2.2"},
      {:ssl_verify_fun, "~> 1.1"},
      {:ex_doc, "~> 0.16", only: :dev},
      {:earmark, "~> 1.2", only: :dev},
      {:mix_test_watch, "~> 0.4", only: [:test, :dev]},
      {:credo, "~> 0.8", only: [:test, :dev]},
      {:benchfella, "~> 0.3", only: [:test, :dev]}
    ]
  end

  defp description do
    """
    River is an http/2 (HTTP2) client for Elixir (a work in progress, though!)
    """
  end

  defp package do
    [
      name: :river,
      maintainers: ["Phil Burrows"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/peburrows/river"}
    ]
  end
end

# bad PUSH_PROMISE payload:
# <<0, 0, 0, 2, 63, 225, 31, 130, 135, 4, 144, 97, 9, 245, 65, 81, 57, 74, 148, 48, 130, 88, 82, 212, 185, 16, 143, 65, 136, 170, 105, 210, 154, 196, 185, 236, 155, 122, 136, 218, 110, 229, 177, 128, 46, 5, 195>>
