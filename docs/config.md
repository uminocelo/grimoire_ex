# Configuration

Every Grimoire site has a `config.exs` at its root — a plain Elixir file
evaluated with `Code.eval_file/1` that must return a map. There is no
custom config-file format to learn; it's just Elixir.

```elixir
%{
  title: "My Site",
  base_url: "https://example.com",
  author: "Jane Doe",
  description: "Notes on Elixir and static sites.",
  paginate: 10,
  permalink: :pretty
}
```

## Required fields

`Grimoire.Config.load/1` raises `ArgumentError` if either is missing:

| Key | Type | Description |
|---|---|---|
| `title` | string | Site title, used in layouts and feeds. |
| `base_url` | string | Canonical URL, e.g. `"https://example.com"`. Used by the `absolute_url`/`relative_url` filters and every generated feed/sitemap URL. Include a path prefix here for a project site (e.g. GitHub Pages' `https://user.github.io/repo`) — `relative_url` picks it up automatically. |

## Optional fields and their defaults

| Key | Type | Default | Description |
|---|---|---|---|
| `author` | string \| `nil` | `nil` | Default site author. |
| `description` | string \| `nil` | `nil` | Site description (feeds, `<meta>` tags in your own layouts). |
| `source` | string | `"."` | Site source directory. Mostly relevant when scripting against `Grimoire.Config`/`Grimoire.Scanner` directly — the CLI's `--source` flag is the usual way to set this. |
| `destination` | string | `"_site"` | Output directory, relative to `source` (overridable with `--dest`). |
| `paginate` | `pos_integer()` \| `false` | `10` | Posts per paginated index page. `false` disables pagination — a single index page with every post. |
| `permalink` | `:pretty` \| `:date` \| `:ordinal` \| string | `:pretty` | Post URL pattern — see below. |
| `feed_posts` | `pos_integer()` | `20` | Most recent posts included in `feed.xml`/`atom.xml`. |
| `timezone` | string | `"UTC"` | Reserved for future use — dates are currently treated as naive (no timezone conversion happens yet). |
| `generate_tags` | boolean | `true` | Set `false` to skip tag archive page generation entirely. |
| `generate_categories` | boolean | `true` | Set `false` to skip category archive page generation entirely. |
| `fingerprint_assets` | boolean | `false` | MD5 cache-busting on `assets/` files — see [`docs/deployment.md`](deployment.md#cache-busting-with-fingerprint_assets). |

## `permalink` patterns

| Pattern | Example output (for a post dated 2024-01-15, slug `hello`) |
|---|---|
| `:pretty` (default) | `/2024/01/15/hello/` |
| `:date` | `/2024/01/15/hello.html` |
| `:ordinal` | `/2024/015/hello/` (day-of-year) |
| a custom string | `"/:year/:slug/"` → `/2024/hello/` — placeholders: `:year`, `:month`, `:day`, `:slug`, `:title`, `:categories` |

A post's own front matter `permalink:` (see
[`docs/front-matter.md`](front-matter.md)) always overrides the site-wide
pattern for that one post.

## Loading config yourself

If you're scripting against Grimoire's modules directly rather than the
CLI, `Grimoire.Config.load/1` takes the site's root directory (the
directory *containing* `config.exs`, not the file path itself):

```elixir
config = Grimoire.Config.load("path/to/site")
```

To override a loaded field (as the CLI does for `--dest`):

```elixir
%{config | destination: "dist"}
```
