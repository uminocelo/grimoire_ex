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
      test_coverage: [summary: [threshold: 80]],
      dialyzer: [plt_add_apps: [:mix, :inets, :eex]],
      docs: docs()
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
  # :inets backs Grimoire.DevServer's httpd. Declaring it here is what
  # actually starts the :inets OTP application at boot — without it,
  # :inets.start(:httpd, opts) fails with {:error, :inets_not_started}
  # outside of a context (like a test) that starts :inets itself.
  #
  # :xmerl (OTP stdlib, not a Hex dependency) is only needed in test, to
  # structurally validate the XML feed/sitemap output — see feed_test.exs.
  defp extra_applications(:test), do: [:logger, :eex, :inets, :xmerl]
  defp extra_applications(_env), do: [:logger, :eex, :inets]

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

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/getting-started.md",
        "docs/site-structure.md",
        "docs/front-matter.md",
        "docs/templates.md",
        "docs/config.md",
        "docs/deployment.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        Content: [
          Grimoire.Config,
          Grimoire.Scanner,
          Grimoire.FrontMatter,
          Grimoire.Markdown,
          Grimoire.Post,
          Grimoire.Page,
          Grimoire.Collection,
          Grimoire.Site
        ],
        Pipeline: [
          Grimoire.Renderer,
          Grimoire.Router,
          Grimoire.Filters.DateToString,
          Grimoire.Filters.DateToXmlschema,
          Grimoire.Filters.XmlEscape,
          Grimoire.Filters.Slugify,
          Grimoire.Filters.RelativeUrl,
          Grimoire.Filters.AbsoluteUrl,
          Grimoire.Filters.UrlHelpers
        ],
        Build: [
          Grimoire.Builder,
          Grimoire.Paginator,
          Grimoire.Tagger,
          Grimoire.Categorizer,
          Grimoire.Feed,
          Grimoire.Sitemap,
          Grimoire.Assets
        ],
        Dev: [
          Grimoire.DevServer,
          Grimoire.Watcher
        ],
        CLI: [
          Grimoire.CLI,
          Grimoire.CLI.Commands,
          Grimoire.CLI.Logger,
          Grimoire.SiteGenerator,
          Mix.Tasks.Grimoire.Build,
          Mix.Tasks.Grimoire.Serve,
          Mix.Tasks.Grimoire.New,
          Mix.Tasks.Grimoire.Clean
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
