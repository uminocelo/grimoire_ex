# Grimoire

A zero-runtime-dependency static site generator for Elixir, built on
[Alembic](https://hexdocs.pm/alembic_template_engine), a Liquid-compatible
template engine. Content is Markdown with YAML-like front matter; layouts
are Alembic templates with inheritance, includes, and filters; the whole
pipeline — front matter and Markdown parsing, routing, rendering, RSS/Atom
feeds, sitemap, asset pipeline, a dev server, and a file watcher — is built
entirely on Elixir/OTP standard library functionality, with Alembic as the
*only* runtime dependency.

Ships two ways: as `mix grimoire.*` tasks for projects already using
Elixir/Mix, and as a standalone `grimoire` escript binary that only needs
Erlang on `PATH`.

## Quick start

```console
$ grimoire new my_blog && cd my_blog
$ grimoire build
$ grimoire serve
✓ Dev server running at http://localhost:4000
```

See [`docs/getting-started.md`](docs/getting-started.md) for the full
walkthrough, verified end-to-end.

## Installation

**As a standalone binary** — build the escript from source and put it on
your `PATH`:

```console
$ mix deps.get && mix escript.build
$ cp grimoire /usr/local/bin/
```

**As a Mix dependency**, if you're scripting against Grimoire's modules
directly or want `mix grimoire.*` tasks inside another Elixir project:

```elixir
def deps do
  [{:grimoire, "~> 0.1.0"}]
end
```

## Documentation

- [`docs/getting-started.md`](docs/getting-started.md) — install → running
  site in under five minutes.
- [`docs/site-structure.md`](docs/site-structure.md) — the directory
  layout every Grimoire site follows.
- [`docs/front-matter.md`](docs/front-matter.md) — post/page front matter
  fields.
- [`docs/templates.md`](docs/templates.md) — the template language,
  Grimoire's variables, and its custom filters.
- [`docs/config.md`](docs/config.md) — every `config.exs` option.
- [`docs/deployment.md`](docs/deployment.md) — GitHub Pages, Netlify,
  Fly.io, or any other static host.
- Full module reference: `mix docs`, or the generated docs once published
  to [HexDocs](https://hexdocs.pm/grimoire).

## Design

- **Zero runtime dependencies beyond Alembic.** Front matter parsing,
  Markdown, XML feed/sitemap generation, the dev server (`:inets`), and
  the file watcher are all built on OTP/Elixir stdlib alone.
- **Parallel by default.** Content parsing and rendering both use
  `Task.async_stream/3` across BEAM schedulers.
- **One broken file doesn't abort the build.** A single post/page render
  failure, or a broken archive-page layout, is recorded in the build
  result and the rest of the site still builds; only a genuine URL
  collision aborts before anything is written.
- **Pretty URLs by default**, with `:date`, `:ordinal`, and custom
  permalink patterns available — see [`docs/config.md`](docs/config.md).

## Contributing / development

```console
$ mix deps.get
$ mix test
$ mix test --cover   # coverage gate: >= 80%
$ mix dialyzer
$ mix format --check-formatted
```

Grimoire depends on Alembic as a local path dependency
(`{:alembic, path: "../alembic"}`) during development — check it out as a
sibling directory.

## License

No license file is committed yet — treat this repository as all rights
reserved until one is added.
