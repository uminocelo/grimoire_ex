defmodule Grimoire.Renderer do
  @moduledoc """
  Bridges Grimoire's content model to Alembic: builds the template
  context, configures Alembic's `_layouts/`/`_includes/` template roots,
  and applies the layout chain (e.g. `_layouts/post.html` →
  `{% extends "base.html" %}` → `_layouts/base.html`) to produce final
  HTML for a post or page.

  ## Template variables reference

  | Variable | Type | Description |
  |---|---|---|
  | `site.title` | `String.t()` | Site title from `config.exs`. |
  | `site.base_url` | `String.t()` | Site's canonical base URL. |
  | `site.author` | `String.t() \| nil` | Default site author. |
  | `site.description` | `String.t() \| nil` | Site description. |
  | `site.posts` | `[map()]` | Published posts (see `Grimoire.Collection.from_posts/1`), as `post.*` maps. |
  | `site.pages` | `[map()]` | Every page, as `page.*` maps. |
  | `site.tags` | `%{String.t() => [map()]}` | Posts grouped by tag. |
  | `site.categories` | `%{String.t() => [map()]}` | Posts grouped by category. |
  | `site.time` | `String.t()` | Build timestamp (ISO 8601), fresh per render. |
  | `post.title` | `String.t()` | Post title. |
  | `post.date` | `String.t()` | Post date, ISO 8601 (`"2024-01-15"`). |
  | `post.url` | `String.t()` | Canonical URL. |
  | `post.excerpt` | `String.t()` | Auto- or front-matter-derived excerpt. |
  | `post.content` | `String.t()` | Rendered Markdown body. |
  | `post.tags` / `post.categories` | `[String.t()]` | Front matter tags/categories. |
  | `post.slug` | `String.t()` | Filename-derived slug. |
  | `post.next` / `post.previous` | `%{"title" =>, "url" =>} \| nil` | Adjacent post in date order (see `Grimoire.Collection.from_posts/1`). |
  | `page.title` | `String.t()` | Page title. |
  | `page.url` | `String.t()` | Canonical URL. |
  | `page.content` | `String.t()` | Rendered Markdown body. |
  | `page.slug` | `String.t()` | Filename-derived slug. |
  | `paginator.posts` | `[map()]` | Posts on the current page (`Grimoire.Paginator`, milestone 4). |
  | `paginator.page` | `pos_integer()` | Current page number. |
  | `paginator.total_pages` | `pos_integer()` | Total page count. |
  | `paginator.previous_page` / `paginator.next_page` | `pos_integer() \| nil` | Adjacent page numbers. |
  | `paginator.previous_page_path` / `paginator.next_page_path` | `String.t() \| nil` | Adjacent page URLs. |

  `content` is also available as a bare top-level variable — the current
  post/page's rendered Markdown body — and, for a post, is aliased as
  `page.content` too (Jekyll-style `page` alias: a post is addressable as
  `page` inside its own layout). See `site_to_map/1`, `post_to_map/1`, and
  `page_to_map/1` for the exact context-building logic.
  """

  alias Grimoire.{Collection, Config, Page, Post, Site}

  @type render_error :: %{reason: term(), source: String.t()}

  @doc """
  Renders `post` through its layout chain. `context["page"]` aliases
  `context["post"]` (Jekyll convention: a post is also addressable as
  `page` inside its own layout).
  """
  @spec render_post(Post.t(), Site.t(), Config.t()) :: {:ok, String.t()} | {:error, render_error()}
  def render_post(post, site, config) do
    publish_base_url(config)
    post_map = post_to_map(post)

    context = %{
      "site" => site_to_map(site),
      "post" => post_map,
      "page" => post_map,
      "content" => post.content_html
    }

    render_with_layout(post.layout || "post", context, post, site)
  end

  @doc "Renders `page` through its layout chain, using `page.*` context."
  @spec render_page(Page.t(), Site.t(), Config.t()) :: {:ok, String.t()} | {:error, render_error()}
  def render_page(page, site, config) do
    publish_base_url(config)

    context = %{
      "site" => site_to_map(site),
      "page" => page_to_map(page),
      "content" => page.content_html
    }

    render_with_layout(page.layout || "page", context, page, site)
  end

  @doc """
  Renders an arbitrary `context` through `layout`, for archive pages
  (pagination/tag/category) that aren't backed by a `%Post{}`/`%Page{}`.
  Falls back to `opts[:fallback]` if `layout` doesn't exist, then to raw
  `context["content"]`, mirroring `render_post/3`'s `"default"` fallback.
  `opts[:source]` labels the page in error tuples (e.g. `"tags/elixir"`).
  """
  @spec render_layout(String.t(), map(), Site.t(), keyword()) ::
          {:ok, String.t()} | {:error, render_error()}
  def render_layout(layout, context, site, opts \\ []) do
    source = Keyword.get(opts, :source, layout)
    fallback = Keyword.get(opts, :fallback)
    render_with_layout(layout, context, %{source_path: source}, site, fallback)
  end

  @doc "`%Site{}` → plain string-keyed map for the template context."
  @spec site_to_map(Site.t()) :: map()
  def site_to_map(site) do
    config = site.config

    %{
      "title" => config.title,
      "base_url" => config.base_url,
      "author" => config.author,
      "description" => config.description,
      "posts" => site.posts |> Collection.from_posts() |> Enum.map(&post_to_map/1),
      "pages" => Enum.map(site.pages, &page_to_map/1),
      "tags" => Map.new(site.tags, fn {tag, posts} -> {tag, Enum.map(posts, &post_to_map/1)} end),
      "categories" =>
        Map.new(site.categories, fn {cat, posts} -> {cat, Enum.map(posts, &post_to_map/1)} end),
      "time" => DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  @doc "`%Post{}` → plain string-keyed context map, `date` as an ISO 8601 string."
  @spec post_to_map(Post.t()) :: map()
  def post_to_map(post) do
    %{
      "title" => post.title,
      "date" => Date.to_iso8601(post.date),
      "url" => post.url,
      "excerpt" => post.excerpt,
      "content" => post.content_html,
      "tags" => post.tags,
      "categories" => post.categories,
      "slug" => post.slug,
      "next" => shallow_post_ref(post.next),
      "previous" => shallow_post_ref(post.previous)
    }
  end

  defp shallow_post_ref(nil), do: nil
  defp shallow_post_ref(%Post{} = post), do: %{"title" => post.title, "url" => post.url}

  @doc "`%Page{}` → plain string-keyed context map."
  @spec page_to_map(Page.t()) :: map()
  def page_to_map(page) do
    %{
      "title" => page.title,
      "url" => page.url,
      "content" => page.content_html,
      "slug" => page.slug
    }
  end

  defp render_with_layout(layout, context, item, site, fallback \\ nil) do
    opts = render_opts(site)

    case Alembic.render_file("#{layout}.html", context, opts) do
      {:ok, html} ->
        {:ok, html}

      {:error, {:loader, _reason}} when is_binary(fallback) ->
        render_with_layout(fallback, context, item, site)

      {:error, {:loader, _reason}} ->
        render_default_layout(context, item, opts)

      {:error, reason} ->
        {:error, %{reason: reason, source: item.source_path}}
    end
  end

  defp render_default_layout(context, item, opts) do
    case Alembic.render_file("default.html", context, opts) do
      {:ok, html} -> {:ok, html}
      {:error, {:loader, _reason}} -> {:ok, context["content"] || ""}
      {:error, reason} -> {:error, %{reason: reason, source: item.source_path}}
    end
  end

  defp render_opts(site) do
    [roots: [Path.join(site.root, "_layouts"), Path.join(site.root, "_includes")]]
  end

  defp publish_base_url(config), do: Application.put_env(:grimoire, :base_url, config.base_url)
end
