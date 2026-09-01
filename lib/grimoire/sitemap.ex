defmodule Grimoire.Sitemap do
  @moduledoc """
  Generates `sitemap.xml` (XML Sitemap protocol 0.9) listing every
  published post's and page's absolute URL, with a `<lastmod>` taken from
  the source file's mtime. Pure iolist string building — no XML library
  needed. Intended output path is `_site/sitemap.xml` (written by
  `Grimoire.Builder`, milestone 4.1).
  """

  alias Grimoire.{Collection, Config, Site}
  alias Grimoire.Filters.UrlHelpers

  @doc "Generates the sitemap document for every published post and page in `site`."
  @spec generate(Site.t(), Config.t()) :: String.t()
  def generate(site, config) do
    Application.put_env(:grimoire, :base_url, config.base_url)

    entries =
      (Collection.from_posts(site.posts) ++ site.pages)
      |> Enum.map_join("\n", &entry/1)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries}
    </urlset>
    """
  end

  defp entry(item) do
    """
      <url>
        <loc>#{UrlHelpers.absolute(item.url)}</loc>
        <lastmod>#{lastmod(item.source_path)}</lastmod>
      </url>
    """
  end

  defp lastmod(source_path) do
    source_path
    |> File.stat!(time: :posix)
    |> Map.fetch!(:mtime)
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end
end
