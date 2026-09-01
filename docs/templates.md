# Templates

Grimoire renders `_layouts/` and `_includes/` with
[Alembic](https://hexdocs.pm/alembic_template_engine), a Liquid-compatible
template engine. If you've used Jekyll or Shopify's Liquid, this will look
familiar; if not, this page covers everything Grimoire's own layouts and
guides use.

## Layout inheritance

A layout `{% extends %}` a parent, overriding one or more named `{% block
%}` regions:

```html
<!-- _layouts/base.html -->
<!doctype html>
<html>
  <head><title>{{ page.title | default: site.title }} · {{ site.title }}</title></head>
  <body>
    {% block content %}{% endblock %}
  </body>
</html>
```

```html
<!-- _layouts/post.html -->
{% extends "base.html" %}
{% block content %}
  <article>{{ content }}</article>
{% endblock %}
```

Chains can go multiple levels deep. `{{ block.super }}` inside a `{%
block %}` renders the parent's version of that block, for extending rather
than fully replacing it.

## Includes

`{% include "header.html" %}` renders `_includes/header.html` in place,
sharing the surrounding template's variables. Grimoire configures Alembic's
template roots as `[_layouts/, _includes/]` for every render, so both
`{% extends %}` targets and `{% include %}` targets resolve by filename
alone — no path prefix needed.

## Variables and control flow

```liquid
{{ post.title }}
{{ post.title | upcase }}

{% if post.tags %}
  <ul>
    {% for tag in post.tags %}<li>{{ tag }}</li>{% endfor %}
  </ul>
{% endif %}

{% assign heading = "Recent posts" %}
<h2>{{ heading }}</h2>
```

A **literal string cannot be piped through a filter directly** —
`{{ "/" | relative_url }}` doesn't parse. Assign it to a variable first:

```liquid
{% assign home_path = "/" %}
<a href="{{ home_path | relative_url }}">Home</a>
```

Alembic ships the full standard Liquid filter catalog (`upcase`, `size`,
`default`, `join`, `first`, `truncate`, ...) — see
[`Alembic.Filters`](https://hexdocs.pm/alembic_template_engine/Alembic.Filters.html)
for the complete list. Everything below is Grimoire-specific, on top of
that.

## Grimoire's template variables

| Variable | Type | Description |
|---|---|---|
| `site.title` | string | From `config.exs`. |
| `site.base_url` | string | From `config.exs`. |
| `site.author` | string \| nil | From `config.exs`. |
| `site.description` | string \| nil | From `config.exs`. |
| `site.posts` | list of post maps | Published posts, newest first. |
| `site.pages` | list of page maps | Every page. |
| `site.tags` | map of tag → posts | Posts grouped by tag. |
| `site.categories` | map of category → posts | Posts grouped by category. |
| `site.time` | string (ISO 8601) | Build timestamp, fresh on every render. |
| `post.title` / `post.date` / `post.url` / `post.excerpt` / `post.content` | — | Post fields — see [`docs/front-matter.md`](front-matter.md). `date` is an ISO 8601 string. |
| `post.tags` / `post.categories` | list of strings | — |
| `post.next` / `post.previous` | `{title, url}` map \| nil | Adjacent post by date; `nil` at the newest/oldest ends. |
| `page.title` / `page.url` / `page.content` | — | Page fields. |
| `paginator.posts` | list of post maps | Posts on the current index page. |
| `paginator.page` / `paginator.total_pages` | integer | Current / total page count. |
| `paginator.previous_page` / `paginator.next_page` | integer \| nil | Adjacent page numbers. |
| `paginator.previous_page_path` / `paginator.next_page_path` | string \| nil | Adjacent page URLs — `nil` at the first/last page. |
| `content` | string | The current post/page's rendered Markdown body — also available as `post.content`/`page.content`. |
| `tag` / `posts` | string / list | Inside a tag archive layout (`_layouts/tag.html`): the tag name and its posts. |
| `category` / `posts` | string / list | Inside a category archive layout (`_layouts/category.html`). |

Inside a post's own layout, the post is *also* addressable as `page` (a
Jekyll convention) — so a shared `base.html` can write `{{ page.title }}`
and have it work for both posts and pages.

## Grimoire's custom filters

| Filter | Example | Output |
|---|---|---|
| `date_to_string` | `{{ post.date \| date_to_string }}` | `"January 15, 2024"` |
| `date_to_string` with a format arg | `{{ post.date \| date_to_string: "%Y-%m-%d" }}` | `"2024-01-15"` |
| `date_to_xmlschema` | `{{ post.date \| date_to_xmlschema }}` | `"2024-01-15T00:00:00Z"` |
| `xml_escape` | `{{ post.title \| xml_escape }}` | `&`/`<`/`>`/`"` escaped |
| `slugify` | `{{ "Elixir Tips" \| slugify }}` | `"elixir-tips"` |
| `relative_url` | `{{ post.url \| relative_url }}` | `base_url`'s path prefix prepended (no-op if none) |
| `absolute_url` | `{{ post.url \| absolute_url }}` | full `scheme://host[:port]/path` prepended |

`date_to_string`'s format string uses `Calendar.strftime/2` directives
(`%Y`, `%m`, `%d`, `%B`, `%-d`, ...), not `strftime(3)`'s C-locale table —
see the [`Calendar` module docs](https://hexdocs.pm/elixir/Calendar.html#strftime/3)
for the full directive list.

## Layout fallback

If a post/page names a layout that doesn't exist, Grimoire falls back to a
layout named `default`; if that doesn't exist either, it renders the
content with no wrapping layout at all rather than failing the build. A
genuine template error (bad syntax, not a missing file) is *not*
swallowed by this fallback — it's reported per-post/page in the build
summary instead. See [`Grimoire.Renderer`](Grimoire.Renderer.html)'s
moduledoc for the exact rules.
