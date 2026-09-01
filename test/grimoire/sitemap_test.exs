defmodule Grimoire.SitemapTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Page, Post, Site, Sitemap}

  defp tmp_file! do
    dir = Path.join(System.tmp_dir!(), "grimoire_sitemap_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    path = Path.join(dir, "source.md")
    File.write!(path, "content")
    path
  end

  defp post(overrides) do
    struct(
      %Post{
        title: "T",
        date: ~D[2024-01-15],
        layout: "post",
        tags: [],
        categories: [],
        excerpt: "",
        published: true,
        slug: "t",
        source_path: tmp_file!(),
        url: "/2024/01/15/t/",
        output_path: "_site/2024/01/15/t/index.html",
        content_html: "",
        raw_meta: %{}
      },
      overrides
    )
  end

  defp page(overrides) do
    struct(
      %Page{
        title: "P",
        layout: "page",
        slug: "p",
        source_path: tmp_file!(),
        url: "/p/",
        output_path: "_site/p/index.html",
        content_html: "",
        raw_meta: %{}
      },
      overrides
    )
  end

  defp xml_parses!(xml) do
    {doc, _rest} = :xmerl_scan.string(String.to_charlist(xml))
    doc
  end

  describe "generate/2" do
    test "lists every published post's and every page's URL as an absolute URL, each with a <lastmod>" do
      posts = [
        post(slug: "a", url: "/2024/01/15/a/"),
        post(slug: "b", url: "/2024/01/20/b/", published: false)
      ]

      pages = [page(slug: "about", url: "/about/")]
      config = struct(%Config{title: "T", base_url: "https://example.com"}, %{})
      site = %Site{config: config, posts: posts, pages: pages}

      xml = Sitemap.generate(site, config)
      doc = xml_parses!(xml)

      assert {:xmlElement, :urlset, _, _, _, _, _, _, _, _, _, _} = doc
      assert xml =~ "<loc>https://example.com/2024/01/15/a/</loc>"
      assert xml =~ "<loc>https://example.com/about/</loc>"
      refute xml =~ "/2024/01/20/b/"

      assert (xml |> String.split("<lastmod>") |> length()) - 1 == 2
    end
  end
end
