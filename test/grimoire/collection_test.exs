defmodule Grimoire.CollectionTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Collection, Post}

  defp post(attrs) do
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
      attrs
    )
  end

  describe "from_posts/1" do
    test "excludes unpublished posts and sorts the rest date-descending" do
      posts = [
        post(date: ~D[2024-01-01], slug: "a", source_path: "a", published: true),
        post(date: ~D[2024-03-01], slug: "b", source_path: "b", published: false),
        post(date: ~D[2024-02-01], slug: "c", source_path: "c", published: true)
      ]

      assert Enum.map(Collection.from_posts(posts), & &1.slug) == ["c", "a"]
    end
  end

  describe "by_tag/1" do
    test "groups a post with multiple tags under each of its tags" do
      posts = [
        post(slug: "a", source_path: "a", tags: ["elixir", "tutorial"], date: ~D[2024-01-01]),
        post(slug: "b", source_path: "b", tags: ["elixir"], date: ~D[2024-02-01])
      ]

      grouped = Collection.by_tag(posts)

      assert Enum.map(grouped["elixir"], & &1.slug) == ["b", "a"]
      assert Enum.map(grouped["tutorial"], & &1.slug) == ["a"]
    end

    test "a post with zero tags contributes to no group" do
      posts = [post(slug: "a", source_path: "a", tags: [])]

      assert Collection.by_tag(posts) == %{}
    end
  end

  describe "by_category/1" do
    test "groups posts by category" do
      posts = [
        post(slug: "a", source_path: "a", categories: ["web"]),
        post(slug: "b", source_path: "b", categories: ["web", "elixir"])
      ]

      grouped = Collection.by_category(posts)

      assert length(grouped["web"]) == 2
      assert Enum.map(grouped["elixir"], & &1.slug) == ["b"]
    end
  end

  describe "paginate/2" do
    test "an exact multiple of per_page produces even pages with no remainder page" do
      posts = for n <- 1..10, do: post(slug: "p#{n}", source_path: "p#{n}")
      pages = Collection.paginate(posts, 5)

      assert length(pages) == 2
      assert Enum.map(pages, & &1.total_pages) == [2, 2]
      assert length(Enum.at(pages, 0).posts) == 5
      assert length(Enum.at(pages, 1).posts) == 5
    end

    test "a remainder produces a final short page" do
      posts = for n <- 1..11, do: post(slug: "p#{n}", source_path: "p#{n}")
      pages = Collection.paginate(posts, 5)

      assert length(pages) == 3
      assert length(Enum.at(pages, 2).posts) == 1
    end

    test "prev/next URLs: nil at the ends, correct paths in between" do
      posts = for n <- 1..11, do: post(slug: "p#{n}", source_path: "p#{n}")
      [page1, page2, page3] = Collection.paginate(posts, 5)

      assert page1.previous_url == nil
      assert page1.next_url == "/page/2/"
      assert page2.previous_url == "/"
      assert page2.next_url == "/page/3/"
      assert page3.previous_url == "/page/2/"
      assert page3.next_url == nil
    end

    test "fewer posts than per_page produces a single page" do
      posts = for n <- 1..3, do: post(slug: "p#{n}", source_path: "p#{n}")
      pages = Collection.paginate(posts, 5)

      assert [%{page: 1, total_pages: 1, previous_url: nil, next_url: nil}] = pages
      assert length(hd(pages).posts) == 3
    end
  end

  describe "related/2" do
    test "returns posts sharing at least one tag, excluding the source post" do
      target = post(slug: "target", source_path: "target", tags: ["elixir"])

      others = [
        post(slug: "a", source_path: "a", tags: ["elixir"], date: ~D[2024-01-01]),
        post(slug: "b", source_path: "b", tags: ["ruby"], date: ~D[2024-01-02]),
        target
      ]

      related = Collection.related(target, others)

      refute Enum.any?(related, &(&1.source_path == target.source_path))
      assert Enum.map(related, & &1.slug) == ["a"]
    end

    test "never returns more than 3 posts" do
      target = post(slug: "target", source_path: "target", tags: ["elixir"])

      others =
        for n <- 1..5,
            do:
              post(
                slug: "p#{n}",
                source_path: "p#{n}",
                tags: ["elixir"],
                date: Date.add(~D[2024-01-01], n)
              )

      assert length(Collection.related(target, others)) == 3
    end
  end
end
