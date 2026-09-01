---
title: Documentation
---

Everything you need to build a site with Grimoire. The full text of each
guide lives in [`docs/`](https://github.com/uminocelo/grimoire_ex/tree/main/docs)
in the repository; this page is the index.

## Guides

- **[Getting started](https://github.com/uminocelo/grimoire_ex/blob/main/docs/getting-started.md)**
  — install → running local site in under five minutes. Also covered as a
  [blog post](/2026/08/25/getting-started-with-grimoire/) here.
- **[Site structure](https://github.com/uminocelo/grimoire_ex/blob/main/docs/site-structure.md)**
  — the directory layout every Grimoire site follows: `_posts/`,
  `_pages/`, `_layouts/`, `_includes/`, `assets/`, and the underscore
  convention that governs what Grimoire processes versus copies verbatim.
- **[Front matter](https://github.com/uminocelo/grimoire_ex/blob/main/docs/front-matter.md)**
  — every post and page field: `title`, `tags`, `categories`, `excerpt`,
  `published`, `layout`, `permalink`.
- **[Templates](https://github.com/uminocelo/grimoire_ex/blob/main/docs/templates.md)**
  — the Alembic template language, Grimoire's full variable reference
  (`site.*`/`post.*`/`page.*`/`paginator.*`), and its six custom filters.
- **[Configuration](https://github.com/uminocelo/grimoire_ex/blob/main/docs/config.md)**
  — every `config.exs` option, with defaults, including permalink
  patterns and pagination.
- **[Deployment](https://github.com/uminocelo/grimoire_ex/blob/main/docs/deployment.md)**
  — GitHub Pages, Netlify, Fly.io, or any other static host. This very
  site deploys via the GitHub Pages recipe in that guide.

## Module reference

Every public module, function, and type is documented with ExDoc — run
`mix docs` from the repository, or browse the published reference once
Grimoire ships to Hex.

## CLI reference

| Command | Does |
|---|---|
| `grimoire new SITE_DIR` | Scaffold a new site. |
| `grimoire build [--source] [--dest] [--verbose] [--clean]` | Full build. |
| `grimoire serve [--source] [--port] [--no-watch]` | Build, then serve with live rebuilds. |
| `grimoire clean [--source] [--dest]` | Delete the output directory. |

Every command above has a `mix grimoire.*` equivalent if you're working
from the Grimoire source tree — see the getting-started guide.
