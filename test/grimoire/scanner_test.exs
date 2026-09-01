defmodule Grimoire.ScannerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Grimoire.Scanner
  import Grimoire.Test.Fixtures

  describe "classify/1" do
    test "classifies every pattern in the table" do
      assert Scanner.classify("_posts/2024-01-01-hello.md") == :post
      assert Scanner.classify("_pages/about.md") == :page
      assert Scanner.classify("_layouts/base.html") == :layout
      assert Scanner.classify("_includes/header.html") == :include
      assert Scanner.classify("assets/css/style.css") == :asset
      assert Scanner.classify("assets/images/logo.png") == :asset
      assert Scanner.classify("robots.txt") == :passthrough
      assert Scanner.classify("favicon.ico") == :passthrough
      assert Scanner.classify("sitemap.xml") == :passthrough
      assert Scanner.classify("manifest.json") == :passthrough
      assert Scanner.classify("config.exs") == :ignore
      assert Scanner.classify(".DS_Store") == :ignore
      assert Scanner.classify("_posts/.hidden.md") == :ignore
    end

    test "a nested file with an unmatched extension at root is ignored, not passthrough" do
      assert Scanner.classify("README.md") == :ignore
    end
  end

  describe "scan/1" do
    setup do
      %{site: Scanner.scan(site_path("content_site"))}
    end

    test "populates config", %{site: site} do
      assert site.config.title == "Content Fixture Site"
    end

    test "posts are parsed in parallel, sorted by date descending, including unpublished", %{
      site: site
    } do
      assert Enum.map(site.posts, & &1.slug) == [
               "unpublished",
               "second-post",
               "hello-grimoire"
             ]
    end

    test "the malformed (non-date-prefixed) post is excluded, not raised", %{site: site} do
      refute Enum.any?(site.posts, &(&1.title == "Malformed Post"))
    end

    test "pages are parsed, sorted by slug", %{site: site} do
      assert Enum.map(site.pages, & &1.slug) == ["about", "contact", "index"]
    end

    test "layouts and includes are excluded from content parsing", %{site: site} do
      refute Enum.any?(site.posts ++ site.pages, &String.contains?(&1.source_path, "_layouts"))
      refute Enum.any?(site.posts ++ site.pages, &String.contains?(&1.source_path, "_includes"))
    end

    test "assets and pass-through files are collected with correct destinations and types", %{
      site: site
    } do
      by_source = Map.new(site.assets, &{Path.basename(&1.source), &1})

      assert by_source["style.css"].type == :asset
      assert by_source["style.css"].destination == "_site/assets/css/style.css"
      assert by_source["app.js"].type == :asset

      assert by_source["robots.txt"].type == :passthrough
      assert by_source["robots.txt"].destination == "_site/robots.txt"
      assert by_source["favicon.ico"].type == :passthrough
    end

    test "_site/, config.exs, and dotfiles never appear in the scan result", %{site: site} do
      root = site_path("content_site")

      all_relative =
        (Enum.map(site.assets, & &1.source) ++ Enum.map(site.posts, & &1.source_path))
        |> Enum.map(&Path.relative_to(&1, root))

      refute Enum.any?(all_relative, &String.starts_with?(&1, "_site/"))
      refute Enum.any?(all_relative, &(&1 == "config.exs"))
      refute Enum.any?(all_relative, &String.contains?(&1, ".DS_Store"))
    end

    test "site.tags contains every unique tag across all scanned posts", %{site: site} do
      assert Map.keys(site.tags) |> Enum.sort() == ["elixir", "tutorial"]
    end

    test "site.categories mirrors Collection.by_category/1's grouping", %{site: site} do
      assert Map.keys(site.categories) == ["web"]
      assert length(site.categories["web"]) == 1
    end

    test "a parse failure is logged, naming the source path, without stopping the scan" do
      log =
        capture_log(fn ->
          site = Scanner.scan(site_path("content_site"))
          assert length(site.posts) == 3
        end)

      assert log =~ "not-date-prefixed.md"
    end
  end
end
