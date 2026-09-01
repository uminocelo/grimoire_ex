# Changelog

## v0.1.0 (unreleased)

Initial MVP release.

### Added

- Content pipeline: front matter parsing (no YAML dependency), Markdown
  rendering, a file scanner that classifies `_posts/`, `_pages/`,
  `_layouts/`, `_includes/`, `assets/`, and root pass-through files.
- Renderer: Alembic-backed layout chain (`{% extends %}`/`{% block %}`),
  template context (`site.*`/`post.*`/`page.*`/`paginator.*`), six custom
  filters (`date_to_string`, `date_to_xmlschema`, `xml_escape`, `slugify`,
  `relative_url`, `absolute_url`).
- Router: pretty/date/ordinal/custom permalink patterns, output path
  computation, URL collision detection.
- Builder: parallel post/page rendering (`Task.async_stream/3`),
  pagination, tag/category archive pages, RSS 2.0 + Atom 1.0 feeds,
  `sitemap.xml`, an asset pipeline with optional MD5 fingerprinting,
  incremental (mtime-aware) rebuilds.
- Dev server (`:inets`-backed, zero deps) and a polling file watcher with
  debounced rebuilds, both wired into `grimoire serve`.
- `mix grimoire.build` / `.serve` / `.new` / `.clean` Mix tasks, and a
  standalone `grimoire` escript exposing the same commands.
- Integration test suite exercising the full pipeline against a 12-post
  fixture site; `mix test --cover` gate at >= 80%.
- Full ExDoc reference and getting-started/site-structure/front-matter/
  templates/config/deployment guides.

### Design constraints

- Zero runtime dependencies beyond Alembic — see the README's Design
  section.
- A single broken post/page/archive-page render is recorded in the build
  result rather than aborting the whole build; only a URL collision does.
