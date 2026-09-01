# Getting started

From nothing to a running local site in under five minutes. Every step
below has been walked through end-to-end exactly as written.

## Prerequisites

Erlang/OTP on `PATH` — that's it. Grimoire ships as a self-contained
escript, so you don't need Elixir installed to *run* it (only to build it
from source, see below).

## 1. Get the `grimoire` binary

If you have the Grimoire source checked out:

```console
$ mix deps.get
$ mix escript.build
$ ./grimoire --version
Grimoire v0.1.0
```

That produces a single `grimoire` file. Copy it onto your `PATH` (e.g.
`cp grimoire /usr/local/bin/`) and drop the `./` from the commands below.

## 2. Scaffold a new site

```console
$ grimoire new my_blog
✓ Created my_blog/
  → cd my_blog
  → grimoire serve  (or: mix grimoire.serve)
$ cd my_blog
```

This creates a minimal but complete site:

```
my_blog/
  config.exs
  _layouts/base.html    _layouts/post.html    _layouts/index.html
  _pages/about.md
  _posts/YYYY-MM-DD-hello-grimoire.md
  assets/css/style.css
```

`grimoire new` never overwrites an existing directory.

## 3. Build it

```console
$ grimoire build
✓ Build complete
Build summary
  archive pages written  2
  assets copied          1
  duration ms            55
  errors                 0
  feed generated         true
  pages written          1
  posts written          1
  sitemap generated      true
```

`_site/` now holds the full static output — HTML, the CSS asset, a
paginated index, `feed.xml`, `atom.xml`, `sitemap.xml`.

## 4. Serve it locally

```console
$ grimoire serve
✓ Dev server running at http://localhost:4000
→ Press Ctrl+C to stop.
```

Open <http://localhost:4000> — you'll see the homepage listing "Hello,
Grimoire!", linking to the post itself and to `/about/`. Edit
`_posts/*-hello-grimoire.md` (or any layout) and save; `grimoire serve`
watches your source files and rebuilds automatically within about half a
second, no restart needed. Pass `--no-watch` to disable that and just
serve the last build. `Ctrl+C` stops the server.

## Where to go from here

- [`docs/site-structure.md`](site-structure.md) — the full directory
  layout Grimoire expects.
- [`docs/front-matter.md`](front-matter.md) — every post/page field.
- [`docs/templates.md`](templates.md) — the template language and
  Grimoire's variables/filters.
- [`docs/config.md`](config.md) — every `config.exs` option.
- [`docs/deployment.md`](deployment.md) — shipping `_site/` to GitHub
  Pages, Netlify, Fly.io, or anywhere else that serves static files.

## Using `mix` instead of the escript

If you're working from the Grimoire source tree itself (contributing to
Grimoire, or building your site from a sibling directory with Alembic as a
path dependency), every command above has a `mix` equivalent:

| Escript | Mix task |
|---|---|
| `grimoire new my_blog` | `mix grimoire.new my_blog` |
| `grimoire build` | `mix grimoire.build` |
| `grimoire serve` | `mix grimoire.serve` |
| `grimoire clean` | `mix grimoire.clean` |

Both run the exact same pipeline (`Grimoire.CLI.Commands`) — pick whichever
fits your workflow.

## Troubleshooting

- **"config.exs is missing required field(s)"** — `title` and `base_url`
  are required; see [`docs/config.md`](config.md).
- **A post doesn't show up in the build** — check the build summary's
  `posts_written` count against how many posts you expect, and look for a
  logged warning naming the file. Common causes: the filename isn't
  `YYYY-MM-DD-slug.md`, front matter is missing `title:`, or the post has
  `published: false`.
- **A page renders with no layout wrapping it** — the layout named in
  `layout:` (or the `post`/`page` default) doesn't exist and neither does
  a `default` layout; see [`docs/templates.md`](templates.md#layout-fallback).
