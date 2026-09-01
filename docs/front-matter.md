# Front matter

Every post and page starts with a `---`-delimited YAML-like block. Grimoire
parses this itself (`Grimoire.FrontMatter`) — there is no YAML dependency,
just a small hand-written parser that understands strings, booleans,
integers, ISO 8601 dates, and one level of `- item` lists.

```markdown
---
title: Hello Grimoire
tags:
  - elixir
  - tutorial
excerpt: A short custom excerpt.
---

The rest of the file is Markdown body content.
```

## Post fields (`_posts/`)

| Key | Type | Required | Default |
|---|---|---|---|
| `title` | string | **yes** | — build fails without it |
| `tags` | list of strings | no | `[]` |
| `categories` | list of strings | no | `[]` |
| `excerpt` | string | no | first `<p>` of the rendered body |
| `published` | boolean | no | `true` |
| `layout` | string | no | `"post"` |
| `permalink` | string | no | derived from `config.exs`'s `permalink` pattern |

**A post's date always comes from its filename** (`_posts/YYYY-MM-DD-slug.md`),
never from front matter — there is no `date:` field to set, even though the
parser recognizes the key. This keeps a post's date and its position in
`_posts/` in sync by construction; renaming the file is how you change a
post's date.

```markdown
---
title: Draft Post
published: false
---

This post is scanned and parsed, but excluded from `site.posts` (published),
skipped by the Builder, and never gets an output file.
```

## Page fields (`_pages/`)

| Key | Type | Required | Default |
|---|---|---|---|
| `title` | string | **yes** | — build fails without it |
| `layout` | string | no | `"page"` |
| `permalink` | string | no | `/:slug/` (or `/:slug.html` under `permalink: :date`) |

A page named `index.md` is special-cased to the site root URL `/`,
regardless of `permalink:`.

## Unrecognized keys

Any key outside the ones above is still parsed and kept (as a string key,
not an atom — see `Grimoire.FrontMatter`'s moduledoc for why), and logged as
a warning. It doesn't fail the build; it's just not read by anything in
Grimoire's own pipeline. This is intentional forward-compatibility, not a
place to plug in custom template variables — Grimoire doesn't currently
expose arbitrary front matter keys to templates, only the fields listed
above.

## Value coercion

- `true` / `false` → `boolean()`
- an all-digit value → `integer()`
- `YYYY-MM-DD` → `Date.t()`
- a `key:` line followed by `  - item` lines → a list of trimmed strings
- everything else → the trimmed string, as written

## Missing a `---` block entirely

A file with no leading `---` block is treated as having empty front
matter (`%{}`) and the whole file as body — which then fails
`title`-required validation and is skipped with a logged warning, the same
as any other malformed post/page (see [`docs/getting-started.md`](getting-started.md)'s
troubleshooting section).
