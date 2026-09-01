defmodule Grimoire.BuilderTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Builder, Config, Renderer, Scanner}

  defp build_fixture_site!(post_count, page_count) do
    dir =
      Path.join(System.tmp_dir!(), "grimoire_builder_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(dir, "_posts"))
    File.mkdir_p!(Path.join(dir, "_pages"))
    File.mkdir_p!(Path.join(dir, "_layouts"))
    File.mkdir_p!(Path.join(dir, "assets/css"))

    File.write!(
      Path.join(dir, "_layouts/base.html"),
      "<html>{% block content %}{% endblock %}</html>"
    )

    File.write!(
      Path.join(dir, "_layouts/post.html"),
      ~s({% extends "base.html" %}{% block content %}<article>{{ content }}</article>{% endblock %})
    )

    File.write!(
      Path.join(dir, "_layouts/page.html"),
      ~s({% extends "base.html" %}{% block content %}<section>{{ content }}</section>{% endblock %})
    )

    File.write!(
      Path.join(dir, "_layouts/index.html"),
      "<ul>{% for post in paginator.posts %}<li>{{ post.title }}</li>{% endfor %}</ul>"
    )

    File.write!(Path.join(dir, "assets/css/style.css"), "body{}")
    File.write!(Path.join(dir, "robots.txt"), "User-agent: *")

    File.write!(Path.join(dir, "config.exs"), """
    %{title: "Fixture", base_url: "https://example.com", paginate: 4}
    """)

    for i <- 1..post_count do
      date = Date.add(~D[2024-01-01], i)
      path = "_posts/#{Date.to_iso8601(date)}-post-#{i}.md"

      File.write!(Path.join(dir, path), """
      ---
      title: Post #{i}
      tags:
        - tag-#{rem(i, 3)}
      categories:
        - cat-#{rem(i, 2)}
      ---

      Body #{i}.
      """)
    end

    for i <- 1..page_count do
      File.write!(Path.join(dir, "_pages/page-#{i}.md"), """
      ---
      title: Page #{i}
      ---

      Page body #{i}.
      """)
    end

    dir
  end

  setup do
    dir = build_fixture_site!(10, 3)
    on_exit(fn -> File.rm_rf!(dir) end)

    config = dir |> Config.load() |> then(&%{&1 | destination: Path.join(dir, "_site")})
    site = Scanner.scan(dir, config)

    %{dir: dir, site: site, config: config}
  end

  describe "build/2" do
    test "a full fixture-site build produces every expected _site/ file and a correct summary", %{
      site: site,
      config: config
    } do
      assert {:ok, summary} = Builder.build(site)

      assert summary.posts_written == 10
      assert summary.pages_written == 3
      assert summary.errors == []

      Enum.each(site.posts, &assert(File.exists?(&1.output_path)))
      Enum.each(site.pages, &assert(File.exists?(&1.output_path)))

      assert File.exists?(Path.join(config.destination, "feed.xml"))
      assert File.exists?(Path.join(config.destination, "atom.xml"))
      assert File.exists?(Path.join(config.destination, "sitemap.xml"))
      assert File.exists?(Path.join(config.destination, "assets/css/style.css"))
      assert File.exists?(Path.join(config.destination, "robots.txt"))
      assert File.exists?(Path.join(config.destination, "index.html"))
    end

    test "parallel rendering produces the same output set as a sequential re-render", %{
      site: site
    } do
      assert {:ok, _summary} = Builder.build(site)

      parallel_html = Map.new(site.posts, &{&1.output_path, File.read!(&1.output_path)})

      sequential_html =
        Map.new(site.posts, fn post ->
          {:ok, html} = Renderer.render_post(post, site, site.config)
          {post.output_path, html}
        end)

      assert parallel_html == sequential_html
    end

    test "a URL collision aborts before any file under _site/ is written", %{
      site: site,
      config: config
    } do
      [first, second | rest] = site.posts
      colliding = %{second | url: first.url}
      site = %{site | posts: [first, colliding | rest]}

      assert {:error, {:url_collisions, _collisions}} = Builder.build(site)
      refute File.exists?(config.destination)
    end

    test "a single post's render failure is recorded but doesn't stop the rest of the build", %{
      site: site,
      dir: dir
    } do
      File.write!(Path.join(dir, "_layouts/broken.html"), "{{ }}")
      [first | rest] = site.posts
      broken = %{first | layout: "broken"}
      site = %{site | posts: [broken | rest]}

      assert {:ok, summary} = Builder.build(site)
      assert summary.posts_written == 9
      assert [{source, _reason}] = summary.errors
      assert source == broken.source_path
      assert summary.pages_written == 3
    end

    test "a broken tag/category/pagination layout is recorded as an error instead of crashing the build",
         %{site: site, dir: dir} do
      File.write!(Path.join(dir, "_layouts/index.html"), "{{ }}")

      assert {:ok, summary} = Builder.build(site)
      assert summary.posts_written == 10
      assert summary.pages_written == 3
      assert length(summary.errors) > 0
      assert Enum.any?(summary.errors, fn {source, _reason} -> source =~ "pagination:" end)
    end
  end

  describe "build/2 archive page precedence" do
    test "a generated archive page is skipped when a post/page already claims its URL", %{
      dir: dir
    } do
      File.write!(Path.join(dir, "_pages/index.md"), """
      ---
      title: Home
      ---

      Hand-authored homepage.
      """)

      config = dir |> Config.load() |> then(&%{&1 | destination: Path.join(dir, "_site")})
      site = Scanner.scan(dir, config)

      assert {:ok, summary} = Builder.build(site)

      # 3 pages: page-1, page-2, page-3, plus the new hand-authored index.
      assert summary.pages_written == 4
      assert File.read!(Path.join(config.destination, "index.html")) =~ "Hand-authored homepage."
    end
  end

  describe "build/2 with clean: true" do
    test "empties the destination first; without it, an existing destination is built into in place",
         %{site: site, config: config} do
      stale_file = Path.join(config.destination, "stale.html")
      File.mkdir_p!(config.destination)
      File.write!(stale_file, "stale")

      assert {:ok, _summary} = Builder.build(site)
      assert File.exists?(stale_file)

      assert {:ok, _summary} = Builder.build(site, clean: true)
      refute File.exists?(stale_file)
    end
  end
end
