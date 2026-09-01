defmodule Grimoire.CategorizerTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Categorizer, Config, Post, Site}

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
    dir =
      Path.join(
        System.tmp_dir!(),
        "grimoire_categorizer_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(Path.join(dir, "_layouts"))
    on_exit(fn -> File.rm_rf!(dir) end)

    Enum.each(layouts, fn {name, html} ->
      File.write!(Path.join(dir, "_layouts/#{name}.html"), html)
    end)

    config = struct(%Config{title: "T", base_url: "https://example.com"}, %{})
    %{site: %Site{root: dir, config: config}, config: config}
  end

  @category_layout "category: {{ category }} - posts: {{ posts | size }}"

  describe "generate_pages/3" do
    test "generates one page per unique category across published posts" do
      %{site: site, config: config} = site_with_layouts(%{"category" => @category_layout})

      posts = [
        post(slug: "a", source_path: "a", categories: ["web", "elixir"]),
        post(slug: "b", source_path: "b", categories: ["web"])
      ]

      pages = Categorizer.generate_pages(posts, site, config)

      assert Enum.map(pages, & &1.category) |> Enum.sort() == ["elixir", "web"]

      web_page = Enum.find(pages, &(&1.category == "web"))
      assert Enum.map(web_page.posts, & &1.slug) |> Enum.sort() == ["a", "b"]
      assert web_page.url == "/categories/web/"
      assert web_page.output_path == "_site/categories/web/index.html"

      elixir_page = Enum.find(pages, &(&1.category == "elixir"))
      assert Enum.map(elixir_page.posts, & &1.slug) == ["a"]
      assert elixir_page.html == "category: elixir - posts: 1"
    end

    test "a category with zero published posts (only on an unpublished post) generates no page" do
      %{site: site, config: config} = site_with_layouts(%{"category" => @category_layout})

      posts = [
        post(slug: "a", source_path: "a", categories: ["web"]),
        post(slug: "draft", source_path: "draft", categories: ["hidden-cat"], published: false)
      ]

      pages = Categorizer.generate_pages(posts, site, config)

      assert Enum.map(pages, & &1.category) == ["web"]
      refute Enum.any?(pages, &(&1.category == "hidden-cat"))
    end

    test "falls back to the \"index\" layout when \"category\" doesn't exist" do
      %{site: site, config: config} = site_with_layouts(%{"index" => "fallback: {{ category }}"})

      [page] =
        Categorizer.generate_pages(
          [post(slug: "a", source_path: "a", categories: ["web"])],
          site,
          config
        )

      assert page.html == "fallback: web"
    end

    test "config.generate_categories: false produces zero pages" do
      %{site: site, config: config} = site_with_layouts(%{"category" => @category_layout})
      config = struct(config, generate_categories: false)

      posts = [post(slug: "a", source_path: "a", categories: ["web"])]

      assert Categorizer.generate_pages(posts, site, config) == []
    end
  end
end
