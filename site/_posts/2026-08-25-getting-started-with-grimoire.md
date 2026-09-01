---
title: Getting started with Grimoire
tags:
  - guide
  - getting-started
excerpt: From nothing to a running local site in under five minutes — install, scaffold, build, serve.
---

Here's the whole workflow, start to finish, exactly as it works today.

## Get the binary

If you have the source checked out:

```console
$ mix deps.get
$ mix escript.build
$ ./grimoire --version
Grimoire v0.1.0
```

That's a single self-contained `grimoire` file — copy it onto your `PATH`
and you're done. No Elixir install needed to *run* it, only Erlang.

## Scaffold a site

```console
$ grimoire new my_blog
✓ Created my_blog/
  → cd my_blog
  → grimoire serve  (or: mix grimoire.serve)
$ cd my_blog
```

You get a minimal but complete site: `config.exs`, three layouts
(`base.html`, `post.html`, `index.html`), an about page, one starter post,
and a stylesheet.

## Build and serve

```console
$ grimoire build
✓ Build complete
...
$ grimoire serve
✓ Dev server running at http://localhost:4000
```

Open `localhost:4000`. Edit the starter post, save, and the dev server
rebuilds automatically — no restart, about half a second. `Ctrl+C` stops
it; `--no-watch` disables the rebuild-on-save if you just want a static
preview.

## Next

- [`docs/front-matter.md`](https://github.com/uminocelo/grimoire_ex/blob/main/docs/front-matter.md)
  for every post/page field.
- [`docs/templates.md`](https://github.com/uminocelo/grimoire_ex/blob/main/docs/templates.md)
  for the template language and Grimoire's variables/filters.
- [`docs/deployment.md`](https://github.com/uminocelo/grimoire_ex/blob/main/docs/deployment.md)
  for shipping to GitHub Pages, Netlify, or Fly.io.

The full guide set lives in the [documentation](/documentation/) page.
