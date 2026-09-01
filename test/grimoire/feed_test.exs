defmodule Grimoire.FeedTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Feed, Post}

  defp config(overrides \\ %{}) do
    struct(
      %Config{title: "Fixture Site", base_url: "https://example.com", author: "Author"},
      overrides
    )
  end

  defp post(overrides) do
    struct(
      %Post{
        title: "T",
        date: ~D[2024-01-15],
        layout: "post",
        tags: [],
        categories: [],
        excerpt: "excerpt",
        published: true,
        slug: "t",
        source_path: "_posts/t.md",
        url: "/2024/01/15/t/",
        output_path: "_site/2024/01/15/t/index.html",
        content_html: "<p>body</p>",
        raw_meta: %{}
      },
      overrides
    )
  end

  defp xml_parses!(xml) do
    {doc, _rest} = :xmerl_scan.string(String.to_charlist(xml))
    doc
  end

  describe "rss/2" do
    test "contains an <rss root element and one <item> per included post, capped at feed_posts" do
      posts = for i <- 1..5, do: post(slug: "p#{i}", source_path: "p#{i}", date: Date.add(~D[2024-01-01], i))

      xml = Feed.rss(posts, config(feed_posts: 3))
      doc = xml_parses!(xml)

      assert {:xmlElement, :rss, _, _, _, _, _, _, _, _, _, _} = doc
      assert (xml |> String.split("<item>") |> length()) - 1 == 3
    end

    test "escapes every title/description, and a title with &, <, \" round-trips through an XML parser" do
      posts = [post(slug: "p", source_path: "p", title: ~s(A & B <tag> "quote"))]

      xml = Feed.rss(posts, config())

      assert xml =~ "A &amp; B &lt;tag&gt; &quot;quote&quot;"
      assert xml_parses!(xml)
    end
  end

  describe "atom/2" do
    test "contains a <feed root element with feed-level and entry-level fields" do
      posts = [post(slug: "p", source_path: "p")]

      xml = Feed.atom(posts, config())
      doc = xml_parses!(xml)

      assert {:xmlElement, :feed, _, _, _, _, _, _, _, _, _, _} = doc
      assert xml =~ "<id>"
      assert xml =~ "<updated>"
      assert xml =~ "<entry>"
      assert xml =~ "<summary>"
      assert xml =~ "<content"
    end
  end
end
