defmodule Grimoire.PaginatorTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Paginator, Post, Site}

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

  defp posts(count) do
    for i <- 1..count do
      post(slug: "post-#{i}", source_path: "_posts/post-#{i}.md", date: Date.add(~D[2024-01-01], i))
    end
  end

  defp site_with_layout(layout_html) do
    dir =
      Path.join(System.tmp_dir!(), "grimoire_paginator_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(dir, "_layouts"))
    on_exit(fn -> File.rm_rf!(dir) end)
    File.write!(Path.join(dir, "_layouts/index.html"), layout_html)

    config = struct(%Config{title: "T", base_url: "https://example.com"}, %{})
    %{site: %Site{root: dir, config: config}, config: config}
  end

  @paginator_layout """
  page {{ paginator.page }}/{{ paginator.total_pages }} - \
  prev: {{ paginator.previous_page_path | default: "none" }} - \
  next: {{ paginator.next_page_path | default: "none" }} - \
  posts: {{ paginator.posts | size }}
  """

  describe "generate_pages/3" do
    test "15 posts with paginate: 5 generates 3 pages" do
      %{site: site, config: config} = site_with_layout(@paginator_layout)
      config = struct(config, paginate: 5)

      pages = Paginator.generate_pages(posts(15), site, config)

      assert Enum.map(pages, & &1.page_number) == [1, 2, 3]
      assert Enum.map(pages, & &1.url) == ["/", "/page/2/", "/page/3/"]

      assert Enum.map(pages, & &1.output_path) == [
               "_site/index.html",
               "_site/page/2/index.html",
               "_site/page/3/index.html"
             ]

      assert Enum.all?(pages, &(length(&1.posts) == 5))
    end

    test "paginator.next_page_path on page 1 is /page/2/, previous_page_path is nil" do
      %{site: site, config: config} = site_with_layout(@paginator_layout)
      config = struct(config, paginate: 5)

      [page1, page2, page3] = Paginator.generate_pages(posts(15), site, config)

      assert page1.html =~ "prev: none"
      assert page1.html =~ "next: /page/2/"
      assert page2.html =~ "prev: / - next: /page/3/"
      assert page3.html =~ "prev: /page/2/ - next: none"
    end

    test "config.paginate: false produces a single index page containing every post" do
      %{site: site, config: config} = site_with_layout(@paginator_layout)
      config = struct(config, paginate: false)

      assert [page] = Paginator.generate_pages(posts(15), site, config)
      assert page.page_number == 1
      assert length(page.posts) == 15
      assert page.url == "/"
      assert page.html =~ "posts: 15"
    end
  end
end
