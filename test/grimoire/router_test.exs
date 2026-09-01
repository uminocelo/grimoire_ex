defmodule Grimoire.RouterTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Page, Post, Router}

  defp config(overrides \\ %{}) do
    struct(%Config{title: "T", base_url: "https://example.com"}, overrides)
  end

  defp post(overrides \\ %{}) do
    struct(
      %Post{
        title: "Hello",
        date: ~D[2024-01-15],
        slug: "hello",
        categories: [],
        permalink: nil
      },
      overrides
    )
  end

  defp page(overrides \\ %{}) do
    struct(%Page{title: "About", slug: "about", permalink: nil}, overrides)
  end

  describe "post_url/2" do
    test ":pretty produces /:year/:month/:day/:slug/" do
      assert Router.post_url(post(), config(permalink: :pretty)) == "/2024/01/15/hello/"
    end

    test ":date produces /:year/:month/:day/:slug.html" do
      assert Router.post_url(post(), config(permalink: :date)) == "/2024/01/15/hello.html"
    end

    test "a custom template replaces placeholders" do
      assert Router.post_url(post(), config(permalink: "/:year/:slug/")) == "/2024/hello/"
    end

    test "a post-level permalink overrides the global pattern for that post only" do
      p = post(permalink: "/custom/path/")
      assert Router.post_url(p, config(permalink: :pretty)) == "/custom/path/"
    end
  end

  describe "page_url/2" do
    test "index.md resolves to the root URL" do
      assert Router.page_url(page(slug: "index"), config()) == "/"
    end

    test "defaults to /:slug/ under :pretty" do
      assert Router.page_url(page(), config(permalink: :pretty)) == "/about/"
    end

    test "an explicit page permalink wins" do
      assert Router.page_url(page(permalink: "/contact-us/"), config()) == "/contact-us/"
    end
  end

  describe "pagination_url/2" do
    test "page 1 resolves to /" do
      assert Router.pagination_url(1) == "/"
    end

    test "page 3 resolves to /page/3/" do
      assert Router.pagination_url(3) == "/page/3/"
    end
  end

  describe "tag_url/2 and category_url/2" do
    test "slugifies names with spaces and mixed case" do
      assert Router.tag_url("Elixir Tips") == "/tags/elixir-tips/"
      assert Router.category_url("Web Dev") == "/categories/web-dev/"
    end
  end

  describe "output_path/2" do
    test "a pretty URL maps to .../index.html" do
      assert Router.output_path("/2024/01/hello/", config()) ==
               "_site/2024/01/hello/index.html"
    end

    test "a file-style URL is used as-is under the destination" do
      assert Router.output_path("/about.html", config()) == "_site/about.html"
    end

    test "the root URL maps to <destination>/index.html" do
      assert Router.output_path("/", config()) == "_site/index.html"
    end
  end

  describe "check_collisions/1" do
    test "reports two sources claiming the same URL together" do
      entries = [
        {"/about/", "_posts/a.md"},
        {"/about/", "_pages/about.md"},
        {"/contact/", "_pages/contact.md"}
      ]

      assert {:error, {:url_collisions, collisions}} = Router.check_collisions(entries)
      assert collisions == [{"/about/", ["_posts/a.md", "_pages/about.md"]}]
    end

    test "returns {:ok} when every URL is unique" do
      entries = [{"/about/", "a.md"}, {"/contact/", "b.md"}]
      assert Router.check_collisions(entries) == {:ok}
    end
  end
end
