defmodule Grimoire.TaggerTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Post, Site, Tagger}

  defp post(overrides) do
    struct(
      %Post{
        title: "T",
        date: ~D[2024-01-01],
        layout: "post",
        tags: [],
        categories: [],
        excerpt: "",
        published: true,
        slug: "t",
        source_path: "_posts/t.md",
        url: "/t/",
        output_path: "_site/t/index.html",
        content_html: "",
        raw_meta: %{}
      },
      overrides
    )
  end

  defp site_with_layouts(layouts) do
    dir = Path.join(System.tmp_dir!(), "grimoire_tagger_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "_layouts"))
    on_exit(fn -> File.rm_rf!(dir) end)

    Enum.each(layouts, fn {name, html} ->
      File.write!(Path.join(dir, "_layouts/#{name}.html"), html)
    end)

    config = struct(%Config{title: "T", base_url: "https://example.com"}, %{})
    %{site: %Site{root: dir, config: config}, config: config}
  end

  @tag_layout "tag: {{ tag }} - posts: {{ posts | size }}"

  describe "generate_pages/3" do
    test "generates one page per unique tag across the given posts, each containing only its posts" do
      %{site: site, config: config} = site_with_layouts(%{"tag" => @tag_layout})

      posts = [
        post(slug: "a", source_path: "a", tags: ["elixir", "tutorial"]),
        post(slug: "b", source_path: "b", tags: ["tutorial"])
      ]

      pages = Tagger.generate_pages(posts, site, config)

      assert Enum.map(pages, & &1.tag) |> Enum.sort() == ["elixir", "tutorial"]

      elixir_page = Enum.find(pages, &(&1.tag == "elixir"))
      assert Enum.map(elixir_page.posts, & &1.slug) == ["a"]
      assert elixir_page.url == "/tags/elixir/"
      assert elixir_page.output_path == "_site/tags/elixir/index.html"
      assert elixir_page.html == "tag: elixir - posts: 1"

      tutorial_page = Enum.find(pages, &(&1.tag == "tutorial"))
      assert Enum.map(tutorial_page.posts, & &1.slug) |> Enum.sort() == ["a", "b"]
    end

    test "a tag with zero published posts (only on an unpublished post) generates no page" do
      %{site: site, config: config} = site_with_layouts(%{"tag" => @tag_layout})

      posts = [
        post(slug: "a", source_path: "a", tags: ["elixir"]),
        post(slug: "draft", source_path: "draft", tags: ["hidden-tag"], published: false)
      ]

      pages = Tagger.generate_pages(posts, site, config)

      assert Enum.map(pages, & &1.tag) == ["elixir"]
      refute Enum.any?(pages, &(&1.tag == "hidden-tag"))
    end

    test "falls back to the \"index\" layout when \"tag\" doesn't exist" do
      %{site: site, config: config} = site_with_layouts(%{"index" => "fallback: {{ tag }}"})

      [page] = Tagger.generate_pages([post(slug: "a", source_path: "a", tags: ["elixir"])], site, config)

      assert page.html == "fallback: elixir"
    end

    test "config.generate_tags: false produces zero pages" do
      %{site: site, config: config} = site_with_layouts(%{"tag" => @tag_layout})
      config = struct(config, generate_tags: false)

      posts = [post(slug: "a", source_path: "a", tags: ["elixir"])]

      assert Tagger.generate_pages(posts, site, config) == []
    end
  end
end
