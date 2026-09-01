defmodule Grimoire.MixProject do
  use Mix.Project

  def project do
    [
      app: :grimoire,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [summary: [threshold: 80]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: extra_applications(Mix.env()),
      mod: {Grimoire.Application, []}
    ]
  end

  # :eex (Elixir stdlib) renders the `grimoire.new` starter templates —
  # it must be an application dependency, not just an available module,
  # or `mix escript.build` won't bundle its .beam files and the escript
  # fails at runtime with EEx undefined.
  #
  # :xmerl (OTP stdlib, not a Hex dependency) is only needed in test, to
  # structurally validate the XML feed/sitemap output — see feed_test.exs.
  defp extra_applications(:test), do: [:logger, :eex, :xmerl]
  defp extra_applications(_env), do: [:logger, :eex]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:alembic, path: "../alembic"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp escript do
    [main_module: Grimoire.CLI, name: "grimoire"]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
