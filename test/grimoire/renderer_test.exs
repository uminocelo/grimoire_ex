defmodule Grimoire.RendererTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Post, Renderer, Scanner, Site}
  import Grimoire.Test.Fixtures

  setup do
    site = Scanner.scan(site_path("content_site"))
    %{site: site, config: site.config}
  end

  describe "render_post/3" do
    test "renders the post nested inside both the post and base layouts, with includes resolved",
         %{site: site, config: config} do
      post = Enum.find(site.posts, &(&1.slug == "hello-grimoire"))

      assert {:ok, html} = Renderer.render_post(post, site, config)
      assert html =~ "<!doctype html>"
      assert html =~ "<article>"
      assert html =~ "Fixture header"
      assert html =~ "First paragraph, the excerpt."
    end

    test "falls back to the \"default\" layout when the post's own layout is missing" do
      dir =
        Path.join(System.tmp_dir!(), "grimoire_renderer_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(dir, "_layouts"))
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "_layouts/default.html"), "<default>{{ content }}</default>")

      site = %Site{root: dir, config: Config.load(site_path("content_site"))}

      post =
        struct(%Post{}, %{
          layout: "does-not-exist",
          content_html: "<p>Raw content</p>",
          source_path: "fake.md",
          tags: [],
          categories: [],
          date: ~D[2024-01-01]
        })

      assert Renderer.render_post(post, site, site.config) ==
               {:ok, "<default><p>Raw content</p></default>"}
    end

    test "falls back to rendering content directly when neither the layout nor \"default\" exist" do
      site = %Site{root: site_path("content_site"), config: Config.load(site_path("content_site"))}

      post =
        struct(%Post{}, %{
          layout: "does-not-exist",
          content_html: "<p>Raw content</p>",
          source_path: "fake.md",
          tags: [],
          categories: [],
          date: ~D[2024-01-01]
        })

      assert Renderer.render_post(post, site, site.config) == {:ok, "<p>Raw content</p>"}
    end

    test "wraps an Alembic render error with the failing source_path" do
      dir =
        Path.join(System.tmp_dir!(), "grimoire_renderer_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(dir, "_layouts"))
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "_layouts/broken.html"), "{{ }}")

      site = %Site{root: dir, config: Config.load(site_path("content_site"))}

      post =
        struct(%Post{}, %{
          layout: "broken",
          content_html: "x",
          source_path: "broken-post.md",
          tags: [],
          categories: [],
          date: ~D[2024-01-01]
        })

      assert {:error, %{reason: _reason, source: "broken-post.md"}} =
               Renderer.render_post(post, site, site.config)
    end
  end

  describe "render_page/3" do
    test "renders using page.* context", %{site: site, config: config} do
      page = Enum.find(site.pages, &(&1.slug == "about"))

      assert {:ok, html} = Renderer.render_page(page, site, config)
      assert html =~ "About this fixture site."
    end
  end

  describe "site_to_map/1, post_to_map/1, page_to_map/1" do
    test "site_to_map/1 uses string keys throughout", %{site: site} do
      map = Renderer.site_to_map(site)
      assert Map.keys(map) |> Enum.all?(&is_binary/1)
      assert map["title"] == "Content Fixture Site"
    end

    test "post_to_map/1's date is an ISO 8601 string, not a Date.t()", %{site: site} do
      post = Enum.find(site.posts, &(&1.slug == "hello-grimoire"))
      map = Renderer.post_to_map(post)
      assert map["date"] == "2024-01-15"
      assert is_binary(map["date"])
    end
  end
end
