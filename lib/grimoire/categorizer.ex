defmodule Grimoire.Categorizer do
  @moduledoc """
  Generates one archive page per unique category across published posts,
  rendered through the `"category"` layout (falling back to `"index"` if
  `"category"` doesn't exist), written to
  `_site/categories/:slug/index.html`.

  Disabled entirely by `config.generate_categories: false`.
  """

  alias Grimoire.{Collection, Config, Post, Renderer, Router, Site}

  @type page :: %{
          category: String.t(),
          posts: [Post.t()],
          url: String.t(),
          output_path: String.t(),
          html: String.t()
        }

  @layout "category"
  @fallback_layout "index"

  @doc """
  Generates every category archive page for `posts` — filtered to
  published internally via `Grimoire.Collection.from_posts/1`, so a
  category that only appears on an unpublished post generates no page.
  Returns `[]` when `config.generate_categories` is `false`. A page whose
  render fails (e.g. a template error in `"category"`/`"index"`) yields
  `{:error, %{reason:, source:}}` instead of raising, so one broken
  layout doesn't abort the whole build.
  """
  @spec generate_pages([Post.t()], Site.t(), Config.t()) ::
          [page() | {:error, Renderer.render_error()}]
  def generate_pages(_posts, _site, %Config{generate_categories: false}), do: []

  def generate_pages(posts, site, config) do
    posts
    |> Collection.from_posts()
    |> Collection.by_category()
    |> Enum.map(fn {category, category_posts} ->
      render_page(category, category_posts, site, config)
    end)
  end

  defp render_page(category, category_posts, site, config) do
    url = Router.category_url(category, config)
    output_path = Router.output_path(url, config)

    context = %{
      "site" => Renderer.site_to_map(site),
      "category" => category,
      "posts" => Enum.map(category_posts, &Renderer.post_to_map/1)
    }

    source = "categories:#{category}"

    case Renderer.render_layout(@layout, context, site, source: source, fallback: @fallback_layout) do
      {:ok, html} ->
        %{category: category, posts: category_posts, url: url, output_path: output_path, html: html}

      {:error, _reason} = error ->
        error
    end
  end
end
