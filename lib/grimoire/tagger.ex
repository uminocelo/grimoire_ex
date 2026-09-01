defmodule Grimoire.Tagger do
  @moduledoc """
  Generates one archive page per unique tag across published posts,
  rendered through the `"tag"` layout (falling back to `"index"` if
  `"tag"` doesn't exist), written to `_site/tags/:slug/index.html`.

  Disabled entirely by `config.generate_tags: false`.
  """

  alias Grimoire.{Collection, Config, Post, Renderer, Router, Site}

  @type page :: %{
          tag: String.t(),
          posts: [Post.t()],
          url: String.t(),
          output_path: String.t(),
          html: String.t()
        }

  @layout "tag"
  @fallback_layout "index"

  @doc """
  Generates every tag archive page for `posts` — filtered to published
  internally via `Grimoire.Collection.from_posts/1`, so a tag that only
  appears on an unpublished post generates no page. Returns `[]` when
  `config.generate_tags` is `false`.
  """
  @spec generate_pages([Post.t()], Site.t(), Config.t()) :: [page()]
  def generate_pages(_posts, _site, %Config{generate_tags: false}), do: []

  def generate_pages(posts, site, config) do
    posts
    |> Collection.from_posts()
    |> Collection.by_tag()
    |> Enum.map(fn {tag, tag_posts} -> render_page(tag, tag_posts, site, config) end)
  end

  defp render_page(tag, tag_posts, site, config) do
    url = Router.tag_url(tag, config)
    output_path = Router.output_path(url, config)

    context = %{
      "site" => Renderer.site_to_map(site),
      "tag" => tag,
      "posts" => Enum.map(tag_posts, &Renderer.post_to_map/1)
    }

    source = "tags:#{tag}"

    {:ok, html} =
      Renderer.render_layout(@layout, context, site, source: source, fallback: @fallback_layout)

    %{tag: tag, posts: tag_posts, url: url, output_path: output_path, html: html}
  end
end
