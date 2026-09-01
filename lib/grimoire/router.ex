defmodule Grimoire.Router do
  @moduledoc """
  Maps posts, pages, pagination, tags, and categories to their canonical
  URLs and `_site/` output paths, and detects URL collisions before a
  build starts.

  ## Permalink patterns

  `:pretty` → `/:year/:month/:day/:slug/`
  `:date` → `/:year/:month/:day/:slug.html`
  `:ordinal` → `/:year/:yday/:slug/`
  A `String.t()` is a custom template with `:year`/`:month`/`:day`/`:slug`/
  `:title`/`:categories` placeholders. A post's own `permalink:` front
  matter overrides `config.permalink` for that post only.
  """

  alias Grimoire.Config

  @doc "Computes a post's canonical URL from its (or the site's) permalink pattern."
  @spec post_url(Grimoire.Post.t(), Config.t()) :: String.t()
  def post_url(post, config) do
    pattern = post.permalink || config.permalink
    build_post_url(pattern, post)
  end

  @doc """
  Computes a page's canonical URL. An explicit `page.permalink` wins;
  `index` slug is special-cased to the site root `/`; otherwise `/:slug/`
  (`:pretty`, the default) or `/:slug.html` (`:date`).
  """
  @spec page_url(Grimoire.Page.t(), Config.t()) :: String.t()
  def page_url(page, config) do
    cond do
      is_binary(page.permalink) -> ensure_trailing_slash(page.permalink)
      page.slug == "index" -> "/"
      config.permalink == :date -> "/#{page.slug}.html"
      true -> "/#{page.slug}/"
    end
  end

  @doc "Page 1 is the site root `/`; page 2+ is `/page/:n/`."
  @spec pagination_url(pos_integer(), Config.t() | nil) :: String.t()
  def pagination_url(page, config \\ nil)
  def pagination_url(1, _config), do: "/"
  def pagination_url(page, _config) when is_integer(page) and page > 1, do: "/page/#{page}/"

  @doc "URL for a tag archive page."
  @spec tag_url(String.t(), Config.t() | nil) :: String.t()
  def tag_url(name, _config \\ nil), do: "/tags/#{slugify(name)}/"

  @doc "URL for a category archive page."
  @spec category_url(String.t(), Config.t() | nil) :: String.t()
  def category_url(name, _config \\ nil), do: "/categories/#{slugify(name)}/"

  @doc """
  Maps a canonical URL to its output file path under `config.destination`.
  A trailing-slash ("pretty") URL gets an `index.html`; a URL already
  ending in a file extension (e.g. `.html`) is used as-is.
  """
  @spec output_path(String.t(), Config.t()) :: String.t()
  def output_path(url, config) do
    if String.ends_with?(url, "/") do
      Path.join([config.destination, String.trim(url, "/"), "index.html"])
    else
      Path.join(config.destination, String.trim_leading(url, "/"))
    end
  end

  @doc """
  Detects URL collisions across every piece of computed content.

  `entries` is a list of `{url, source_path}` tuples. Returns `{:ok}` when
  every URL is unique, or `{:error, {:url_collisions, [{url,
  [source_path]}]}}` naming every URL claimed by more than one source.
  """
  @spec check_collisions([{String.t(), String.t()}]) ::
          {:ok} | {:error, {:url_collisions, [{String.t(), [String.t()]}]}}
  def check_collisions(entries) do
    entries
    |> Enum.group_by(fn {url, _source} -> url end, fn {_url, source} -> source end)
    |> Enum.filter(fn {_url, sources} -> length(sources) > 1 end)
    |> case do
      [] -> {:ok}
      collisions -> {:error, {:url_collisions, collisions}}
    end
  end

  @doc "Downcases, strips punctuation, and dash-separates a name for use as a URL segment."
  @spec slugify(String.t()) :: String.t()
  def slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp build_post_url(:pretty, post), do: "/#{date_path(post.date)}/#{post.slug}/"
  defp build_post_url(:date, post), do: "/#{date_path(post.date)}/#{post.slug}.html"

  defp build_post_url(:ordinal, post) do
    "/#{pad(post.date.year, 4)}/#{pad(Date.day_of_year(post.date), 3)}/#{post.slug}/"
  end

  defp build_post_url(template, post) when is_binary(template), do: expand_template(template, post)

  defp date_path(%Date{year: y, month: m, day: d}), do: "#{pad(y, 4)}/#{pad(m, 2)}/#{pad(d, 2)}"

  defp expand_template(template, post) do
    %Date{year: y, month: m, day: d} = post.date

    template
    |> String.replace(":year", pad(y, 4))
    |> String.replace(":month", pad(m, 2))
    |> String.replace(":day", pad(d, 2))
    |> String.replace(":slug", post.slug)
    |> String.replace(":title", slugify(post.title))
    |> String.replace(":categories", Enum.map_join(post.categories, "/", &slugify/1))
  end

  defp ensure_trailing_slash(url) do
    if String.ends_with?(url, "/"), do: url, else: url <> "/"
  end

  defp pad(n, width), do: n |> Integer.to_string() |> String.pad_leading(width, "0")
end
