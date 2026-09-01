defmodule Grimoire.Paginator do
  @moduledoc """
  Splits published posts into paginated index pages and renders each
  through the `"index"` layout, injecting `paginator.*` context (see
  `Grimoire.Renderer`'s template variables reference).

  Page 1 is the site root (`/`, `_site/index.html`); page 2+ is
  `/page/:n/` (`_site/page/:n/index.html`). `config.paginate: false`
  produces a single page holding every post.
  """

  alias Grimoire.{Collection, Config, Post, Renderer, Router, Site}

  @type page :: %{
          page_number: pos_integer(),
          posts: [Post.t()],
          prev_url: String.t() | nil,
          next_url: String.t() | nil,
          url: String.t(),
          output_path: String.t(),
          html: String.t()
        }

  @layout "index"

  @doc """
  Generates every paginated index page for `posts` — filtered to
  published and sorted date-descending internally via
  `Grimoire.Collection.from_posts/1`, so callers can pass a site's raw
  post list.
  """
  @spec generate_pages([Post.t()], Site.t(), Config.t()) :: [page()]
  def generate_pages(posts, site, config) do
    posts
    |> Collection.from_posts()
    |> chunk(config.paginate)
    |> Enum.map(&render_page(&1, site, config))
  end

  defp chunk(posts, false) do
    [%{page_number: 1, posts: posts, total_pages: 1, prev_url: nil, next_url: nil}]
  end

  defp chunk(posts, per_page) when is_integer(per_page) and per_page > 0 do
    posts
    |> Collection.paginate(per_page)
    |> Enum.map(fn %{posts: ps, page: n, total_pages: total, previous_url: prev, next_url: nxt} ->
      %{page_number: n, posts: ps, total_pages: total, prev_url: prev, next_url: nxt}
    end)
  end

  defp render_page(page, site, config) do
    url = Router.pagination_url(page.page_number, config)
    output_path = Router.output_path(url, config)

    context = %{
      "site" => Renderer.site_to_map(site),
      "paginator" => paginator_context(page)
    }

    source = "pagination:page-#{page.page_number}"
    {:ok, html} = Renderer.render_layout(@layout, context, site, source: source)

    %{
      page_number: page.page_number,
      posts: page.posts,
      prev_url: page.prev_url,
      next_url: page.next_url,
      url: url,
      output_path: output_path,
      html: html
    }
  end

  defp paginator_context(page) do
    %{
      "posts" => Enum.map(page.posts, &Renderer.post_to_map/1),
      "page" => page.page_number,
      "total_pages" => page.total_pages,
      "previous_page" => if(page.page_number > 1, do: page.page_number - 1),
      "next_page" => if(page.page_number < page.total_pages, do: page.page_number + 1),
      "previous_page_path" => page.prev_url,
      "next_page_path" => page.next_url
    }
  end
end
