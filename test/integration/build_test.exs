defmodule Grimoire.Integration.BuildTest do
  @moduledoc """
  End-to-end verification of the full Grimoire build pipeline against
  `test/fixtures/sample_site/` (12 posts — 11 published, 1 draft — 2
  pages, `paginate: 5`). This is the MVP's primary quality gate — see
  `.plan/branches/1/milestones/6/6.1.md`.
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Grimoire.{Builder, Collection, Config, Scanner}

  @fixture Path.expand("../fixtures/sample_site", __DIR__)
  @tmp_root Path.expand("../tmp", __DIR__)
  @destination Path.join(@tmp_root, "sample_site_output")

  setup do
    on_exit(fn -> File.rm_rf!(@tmp_root) end)

    config = @fixture |> Config.load() |> then(&%{&1 | destination: @destination})
    site = Scanner.scan(@fixture, config)
    assert {:ok, summary} = Builder.build(site)

    %{site: site, config: config, summary: summary}
  end

  describe "post and page output" do
    test "post output HTML exists and contains the rendered (not literal) title", %{site: site} do
      post = Enum.find(site.posts, &(&1.slug == "post-1"))
      html = File.read!(post.output_path)

      assert html =~ "<h1>Post 1</h1>"
      refute html =~ "{{ post.title }}"
    end

    test "the unpublished post has no output file", %{site: site} do
      draft = Enum.find(site.posts, &(&1.slug == "post-12-draft"))
      refute File.exists?(draft.output_path)
    end

    test "the layout chain nests post content inside both the post and base layouts", %{
      site: site
    } do
      post = Enum.find(site.posts, &(&1.slug == "post-1"))
      html = File.read!(post.output_path)

      assert html =~ "<!doctype html>"
      assert html =~ "<article>"
      assert html =~ "First paragraph of post 1"
    end

    test "tags appear in the rendered post HTML", %{site: site} do
      post = Enum.find(site.posts, &(&1.slug == "post-1"))
      html = File.read!(post.output_path)

      assert html =~ "elixir"
      assert html =~ "tutorial"
    end

    test "post.next/post.previous are correct across the published, sorted collection", %{
      site: site
    } do
      published = Collection.from_posts(site.posts)
      newest = List.first(published)
      oldest = List.last(published)

      assert newest.slug == "post-11"
      assert newest.next == nil
      assert newest.previous.slug == "post-10"

      assert oldest.slug == "post-1"
      assert oldest.previous == nil
      assert oldest.next.slug == "post-2"
    end

    test "both fixture pages exist, nested in the page then base layouts", %{site: site} do
      assert length(site.pages) == 2

      Enum.each(site.pages, fn page ->
        assert File.exists?(page.output_path)
        html = File.read!(page.output_path)
        assert html =~ "<!doctype html>"
        assert html =~ "<article>"
      end)
    end
  end

  describe "pagination, tags, feed, sitemap, assets" do
    test "11 posts with paginate: 5 splits into 5/5/1 with no page/4/", %{config: config} do
      page1 = Path.join(config.destination, "index.html")
      page2 = Path.join(config.destination, "page/2/index.html")
      page3 = Path.join(config.destination, "page/3/index.html")
      page4 = Path.join(config.destination, "page/4/index.html")

      assert File.exists?(page1)
      assert File.exists?(page2)
      assert File.exists?(page3)
      refute File.exists?(page4)

      assert li_count(page1) == 5
      assert li_count(page2) == 5
      assert li_count(page3) == 1
    end

    test "paginator.next_page_path on page 1 is /page/2/, previous_page_path on page 2 is /", %{
      config: config
    } do
      page1 = File.read!(Path.join(config.destination, "index.html"))
      page2 = File.read!(Path.join(config.destination, "page/2/index.html"))

      assert page1 =~ ~s(href="/page/2/")
      assert page2 =~ ~s(href="/")
    end

    test "tag pages exist for elixir/tutorial/web, none for the zero-published-post tag", %{
      config: config
    } do
      assert File.exists?(Path.join(config.destination, "tags/elixir/index.html"))
      assert File.exists?(Path.join(config.destination, "tags/tutorial/index.html"))
      assert File.exists?(Path.join(config.destination, "tags/web/index.html"))
      refute File.exists?(Path.join(config.destination, "tags/draft-only/index.html"))
    end

    test "feed.xml is RSS 2.0 and contains every published title up to feed_posts", %{
      site: site,
      config: config
    } do
      xml = File.read!(Path.join(config.destination, "feed.xml"))
      assert xml =~ "<rss"

      Enum.each(Collection.from_posts(site.posts), fn post -> assert xml =~ post.title end)
    end

    test "atom.xml is an Atom 1.0 feed", %{config: config} do
      xml = File.read!(Path.join(config.destination, "atom.xml"))
      assert xml =~ "<feed"
    end

    test "sitemap.xml lists every published post's and every page's URL, all absolute", %{
      site: site,
      config: config
    } do
      xml = File.read!(Path.join(config.destination, "sitemap.xml"))

      expected =
        (Collection.from_posts(site.posts) ++ site.pages)
        |> MapSet.new(&(config.base_url <> &1.url))

      listed =
        ~r{<loc>(.*?)</loc>}
        |> Regex.scan(xml)
        |> MapSet.new(fn [_, url] -> url end)

      assert listed == expected
      assert Enum.all?(listed, &String.starts_with?(&1, "https://"))
    end

    test "assets are copied verbatim; robots.txt/favicon.ico pass through", %{config: config} do
      assert File.read!(Path.join(config.destination, "assets/css/style.css")) ==
               File.read!(Path.join(@fixture, "assets/css/style.css"))

      assert File.read!(Path.join(config.destination, "assets/js/app.js")) ==
               File.read!(Path.join(@fixture, "assets/js/app.js"))

      assert File.exists?(Path.join(config.destination, "robots.txt"))
      assert File.exists?(Path.join(config.destination, "favicon.ico"))
    end
  end

  describe "build result" do
    test "the clean fixture's result matches every expected count", %{summary: summary} do
      assert summary.posts_written == 11
      assert summary.pages_written == 2
      assert summary.feed_generated == true
      assert summary.sitemap_generated == true
      assert summary.errors == []
    end
  end

  describe "error handling" do
    test "a post missing title: is excluded with a logged warning; the rest of the build succeeds" do
      dir = Path.join(@tmp_root, "broken_missing_title")
      File.rm_rf!(dir)
      File.cp_r!(@fixture, dir)

      File.write!(Path.join(dir, "_posts/2024-01-13-no-title.md"), """
      ---
      tags:
        - elixir
      ---

      This post has no title front matter.
      """)

      config = dir |> Config.load() |> then(&%{&1 | destination: Path.join(dir, "_site")})

      log =
        capture_log(fn ->
          site = Scanner.scan(dir, config)
          assert length(site.posts) == 12

          assert {:ok, summary} = Builder.build(site)
          assert summary.posts_written == 11
          assert summary.errors == []
        end)

      assert log =~ "no-title"
    end

    test "a broken template layout is recorded in result.errors instead of aborting the build" do
      dir = Path.join(@tmp_root, "broken_layout")
      File.rm_rf!(dir)
      File.cp_r!(@fixture, dir)

      config = dir |> Config.load() |> then(&%{&1 | destination: Path.join(dir, "_site")})
      site = Scanner.scan(dir, config)

      target = Enum.find(site.posts, &(&1.slug == "post-1"))
      broken = %{target | layout: "broken"}
      File.write!(Path.join(dir, "_layouts/broken.html"), "{{ }}")
      posts = Enum.map(site.posts, &if(&1.slug == "post-1", do: broken, else: &1))
      site = %{site | posts: posts}

      assert {:ok, summary} = Builder.build(site)
      assert summary.posts_written == 10
      assert Enum.any?(summary.errors, fn {source, _reason} -> source == broken.source_path end)
    end
  end

  defp li_count(path) do
    path |> File.read!() |> String.split("<li>") |> length() |> Kernel.-(1)
  end
end
