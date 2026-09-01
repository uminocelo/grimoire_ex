# AGENTS.md — Grimoire

Grimoire is a zero-runtime-dependency static site generator for Elixir, built on [Alembic](https://hexdocs.pm/alembic_template_engine) (a Liquid-compatible template engine). Ships as both `mix grimoire.*` tasks and a standalone escript binary.

## Essential commands

| Command | Purpose |
|---|---|
| `mix deps.get` | Fetch dependencies |
| `mix test` | Run all tests |
| `mix test --cover` | Coverage gate (≥80% required) |
| `mix format --check-formatted` | Format check (line length 100) |
| `mix compile --warnings-as-errors` | Strict compile |
| `mix dialyzer` | Static analysis (PLT includes `:mix`, `:inets`, `:eex`) |
| `mix escript.build` | Build standalone `grimoire` binary |
| `mix grimoire.build` | Build site from source |
| `mix grimoire.serve` | Build + dev server + file watcher |
| `mix grimoire.new PATH` | Scaffold a new site |
| `mix grimoire.clean` | Delete output directory |
| `mix docs` | Generate ExDoc documentation |

## Build pipeline

```
Config.load → Scanner.scan → Builder.build
```

The `Builder` orchestrates in sequence:
1. `Router.check_collisions` — abort-fast if two posts/pages claim the same URL
2. Prepare destination directory
3. Render posts + pages in parallel via `Task.async_stream/3`
4. Generate tag/category archive pages
5. Generate paginated index pages (page 1 = homepage)
6. Generate RSS 2.0 + Atom 1.0 feeds
7. Generate sitemap
8. Copy static assets

Error resilience: a single post/page render failure is recorded in the summary's `:errors` and does not stop the rest of the build. Only URL collisions abort before any `_site/` file is written.

## Module organization

| Group | Modules |
|---|---|
| **Content** | `Config`, `Scanner`, `FrontMatter`, `Markdown`, `Post`, `Page`, `Collection`, `Site` |
| **Pipeline** | `Renderer`, `Router`, `Filters.*` (DateToString, DateToXmlschema, XmlEscape, Slugify, RelativeUrl, AbsoluteUrl, UrlHelpers) |
| **Build** | `Builder`, `Paginator`, `Tagger`, `Categorizer`, `Feed`, `Sitemap`, `Assets` |
| **Dev** | `DevServer`, `Watcher` |
| **CLI** | `CLI`, `Commands`, `Logger`, `SiteGenerator`, `Mix.Tasks.Grimoire.*` |

## Architecture & data flow

- **`%Site{}`** — the fully scanned representation: config + posts + pages + assets + tags + categories. Built by `Scanner.scan/1`, consumed by `Renderer` and `Builder`.
- **`%Post{}`** — parsed from `_posts/YYYY-MM-DD-slug.md`. Date is **always derived from the filename**, never from front matter. `url`/`output_path` computed via `Router`.
- **`%Page{}`** — parsed from `_pages/slug.md`. `index.md` is special-cased to the site root `/`.
- **`%Config{}`** — loaded from `config.exs` (plain Elixir file, `Code.eval_file/1`). Requires `:title` and `:base_url`.
- **`Renderer`** — bridges to Alembic: builds string-keyed context maps, applies layout chain (e.g. `post.html` → extends `base.html`). Post content is available as `{{ content }}`, `{{ post.content }}`, and `{{ page.content }}` (Jekyll compatibility alias).
- **`Router`** — permalink patterns: `:pretty` (`/:year/:month/:day/:slug/`), `:date` (`/:year/:month/:day/:slug.html`), `:ordinal` (`/:year/:yday/:slug/`), or custom string templates with `:year`/`:month`/`:day`/`:slug`/`:title`/`:categories` placeholders.
- **`FrontMatter`** — hand-written line-by-line parser (no YAML dep). Known keys (`title`, `date`, `layout`, `tags`, etc.) become atoms via whitelisted `String.to_atom/1`. Unknown keys stay as strings to prevent atom-table exhaustion.
- **`CLI.Commands`** — shared by both `mix grimoire.*` tasks and the escript. Only argument parsing and process startup differ.
- **`Application`** — starts `DynamicSupervisor` (`Grimoire.ServeSupervisor`) and registers Alembic custom filters at boot.
- **`base_url`** — shared across modules via `Application.put_env(:grimoire, :base_url, ...)` before every render, because Alembic filters (`UrlHelpers`, etc.) receive only `(value, args)` with no template context.

## Key patterns & conventions

- **Parallel by default**: `Task.async_stream/3` with `max_concurrency: System.schedulers_online()` for content parsing and rendering.
- **Zero runtime deps**: Markdown, front matter, XML feeds/sitemap, dev server (`:inets`), file watcher — all built on OTP/Elixir stdlib alone.
- **Graceful error handling**: render failures are accumulated, not raised. A broken tag/category/pagination layout doesn't crash the build.
- **Author content wins**: generated archive pages (tag/category/pagination) that collide with a real post/page URL are skipped.
- **Content fingerprinting**: the `Watcher` uses `:erlang.phash2/1` of file bytes, not mtime, to detect changes (mtime has 1-second resolution on many filesystems).
- **`@doc` + `@spec`** on every public function. `@doc false` on GenServer callbacks.
- **`@behaviour Alembic.Filter`** for all `Grimoire.Filters.*` modules (must implement `name/0` and `apply/2`).
- **`use GenServer, restart: :transient`** for DevServer and Watcher.

## Important gotchas

1. **Alembic is a local path dependency**: `{:alembic, path: "../alembic"}`. It must be checked out as a sibling directory. CI clones `uminocelo/alembic_ex` to `../alembic`.
2. **`:eex` and `:inets` as `extra_applications`**: these must be declared in `mix.exs` or the escript won't bundle their `.beam` files, causing runtime failures. `:xmerl` is test-only.
3. **Post date is filename-only**: a front matter `date:` field is ignored for the struct but preserved in `raw_meta`.
4. **`index.md` → site root `/`**: any `_pages/index.md` becomes the homepage, overriding the generated paginator page 1.
5. **Dev server is NOT production-grade**: uses `:inets` `httpd`. Only for local preview.
6. **`config.exs` is evaluated with `Code.eval_file/1`**: it must return a plain map. No safety sandboxing.
7. **Starter templates are compile-time embedded** in `SiteGenerator` via `@external_resource` + `File.read!/1` — they ship inside the escript binary.
8. **The `site/` directory is the dogfood site**: Grimoire builds its own documentation site with `mix grimoire.build --source site`, deployed to GitHub Pages.
9. **Coverage threshold is 80%**: `mix test --cover` will fail below it.
10. **`mix compile --warnings-as-errors`** is enforced in CI — treat warnings as errors.
11. **`base_url` via Application env**: `Renderer.publish_base_url/1` sets `Application.put_env(:grimoire, :base_url, ...)` before every render so filters can read it back. Never use a different mechanism.
12. **File watcher is poll-based**: `:timer.send_interval` (default 300ms poll / 200ms debounce), no native FS events. Uses content hashing, not mtime.

## Testing approach

- **Unit tests** in `test/grimoire/` — most use `async: true`. Use `Grimoire.Test.Fixtures.site_path/1` to locate fixture directories.
- **Integration tests** in `test/integration/` — `async: false` (shared tmp dir). Full end-to-end build against `test/fixtures/sample_site/`.
- **Mix task tests** in `test/mix/tasks/`.
- **Temp directories** for per-test files: `Path.join(System.tmp_dir!(), "grimoire_#{test_name}_#{System.unique_integer([:positive])}")`.
- **DevServer/Watcher tests** use unique names (`:"dev_server_test_#{System.unique_integer([:positive])}"`) and random ports for isolation.
- Feed tests use `:xmerl_scan.string/1` for XML structural validation.
- Error/warning log output tested with `ExUnit.CaptureLog.capture_log/1`.
- Fixture sites: `content_site` (parsing fixtures), `sample_site` (full build), `minimal_site`, `missing_required_site`.

## File structure

```
lib/
  grimoire.ex                     # root module
  grimoire/                       # core modules
  grimoire/cli/                   # CLI commands + logger
  grimoire/filters/               # Alembic filter implementations
  mix/tasks/                      # Mix task definitions
test/
  grimoire/                       # unit tests
  support/                        # test helpers
  mix/tasks/                      # mix task tests
  integration/                    # integration tests
  fixtures/                       # fixture site directories
priv/starter/                     # EEx templates for `grimoire new`
site/                             # Grimoire's own dogfood site
docs/                             # documentation markdown files
```

## CI workflow

The CI workflow (`ci.yml`) runs:
1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors` (dev + test env)
3. `mix test`
4. `mix test --cover`

The deploy workflow (`deploy-pages.yml`) builds the dogfood site and deploys to GitHub Pages. Both check out Alembic as a sibling.