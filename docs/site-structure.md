# Site directory structure

This is Grimoire's public contract: the canonical layout every site built
with Grimoire follows. It is designed once, here, and every later stage of
the pipeline (Scanner, Router, Builder, DevServer, Watcher) builds against
it as given.

```
my_site/                    ← site root (passed to grimoire.build)
  config.exs                ← site configuration (native Elixir map)
  _posts/                   ← blog posts (date-prefixed .md files)
    2024-01-15-hello.md
  _pages/                   ← static pages (.md files)
    about.md
    contact.md
  _layouts/                 ← Alembic layout templates
    base.html
    post.html
    page.html
  _includes/                ← Alembic partial templates
    header.html
    footer.html
    nav.html
  assets/                   ← static files (copied verbatim)
    css/
    js/
    images/
  robots.txt                ← root-level pass-through files
  favicon.ico
  _site/                    ← OUTPUT (generated, gitignored)
```

## The underscore convention

**Any file or directory at the site root whose name begins with `_` is
processed by Grimoire.** Everything else at the site root is copied
verbatim into `_site/` (see [`docs/config.md`](config.md) for the
`destination` config option that controls the output directory name).

This is the entire rule the Scanner uses to decide what to parse versus what
to pass through — there is no separate allowlist of "special" top-level
names beyond the ones documented below. A file named `_drafts/foo.md` is
just as much "processed by Grimoire" as `_posts/foo.md`, even before a given
milestone implements support for it.

The one exception baked into the Scanner is `config.exs` itself: it does
not start with `_`, but it is never treated as a pass-through file — it is
always Grimoire's own configuration entry point, never copied into
`_site/`. `_site/` itself is always ignored as scan input, since it is scan
*output*.

## Directories, by role

| Path | Processed by Grimoire? | Required for a minimal build? |
|---|---|---|
| `config.exs` | Yes — always the config entry point, never copied | **Required.** `Grimoire.Config.load/1` raises without a `config.exs` providing at least `:title` and `:base_url`. |
| `_posts/` | Yes — parsed as blog posts | Optional. A site with zero posts still builds; `site.posts` is just `[]`. |
| `_pages/` | Yes — parsed as static pages | Optional, same reasoning as `_posts/`. |
| `_layouts/` | Yes — Alembic layout templates, not parsed as content | **Required** if `_posts/` or `_pages/` is non-empty — a post/page with no matching layout (and no `default` fallback) renders its content with no wrapping layout, which is a degraded but non-fatal outcome (see `Grimoire.Renderer`'s layout fallback). |
| `_includes/` | Yes — Alembic partial templates, not parsed as content | Optional — only needed if a layout uses `{% include %}`. |
| `assets/` | Yes — files collected and copied verbatim to `_site/assets/` | Optional. |
| Root pass-through files (`robots.txt`, `favicon.ico`, `CNAME`, `.nojekyll`, ...) | No — copied verbatim to `_site/` root | Optional. |
| `_site/` | No — build *output*, never scanned as input | N/A — generated, gitignored. |

A **minimal buildable site** is therefore just a `config.exs` with `:title`
and `:base_url` set. Everything else is additive.

## Content file naming

- Posts in `_posts/` are named `YYYY-MM-DD-slug.md` — the date and slug are
  both derived from the filename (see `Grimoire.Post.from_file/2`).
- Pages in `_pages/` are named `slug.md`, with `index.md` special-cased to
  the site root URL `/`.
