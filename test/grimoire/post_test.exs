defmodule Grimoire.PostTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Post}
  alias Grimoire.FrontMatter.MissingFieldError
  import Grimoire.Test.Fixtures

  setup do
    %{config: Config.load(site_path("content_site"))}
  end

  describe "from_file/2" do
    test "populates every struct field correctly", %{config: config} do
      path = Path.join(site_path("content_site"), "_posts/2024-01-15-hello-grimoire.md")
      post = Post.from_file(path, config)

      assert post.title == "Hello Grimoire"
      assert post.date == ~D[2024-01-15]
      assert post.layout == "post"
      assert post.tags == ["elixir", "tutorial"]
      assert post.categories == []
      assert post.published == true
      assert post.slug == "hello-grimoire"
      assert post.source_path == path
      assert post.url == "/2024/01/15/hello-grimoire/"
      assert post.output_path == "_site/2024/01/15/hello-grimoire/index.html"
      assert post.content_html =~ "First paragraph, the excerpt."
      assert post.raw_meta.title == "Hello Grimoire"
    end

    test "auto-extracts the excerpt as the first paragraph", %{config: config} do
      path = Path.join(site_path("content_site"), "_posts/2024-01-15-hello-grimoire.md")
      post = Post.from_file(path, config)

      assert post.excerpt == "First paragraph, the excerpt."
    end

    test "an explicit front matter excerpt: overrides auto-extraction", %{config: config} do
      path = Path.join(site_path("content_site"), "_posts/2024-01-20-second-post.md")
      post = Post.from_file(path, config)

      assert post.excerpt == "An explicit excerpt override."
      assert post.categories == ["web"]
    end

    test "a published: false post still produces a %Post{} with the flag preserved", %{
      config: config
    } do
      path = Path.join(site_path("content_site"), "_posts/2024-02-01-unpublished.md")
      post = Post.from_file(path, config)

      assert %Post{published: false, title: "Unpublished Draft"} = post
    end

    test "raises MissingFieldError naming :title when front matter has no title", %{
      config: config
    } do
      dir = Path.join(System.tmp_dir!(), "grimoire_post_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "2024-01-01-no-title.md")
      File.write!(path, "---\ntags:\n  - x\n---\nBody.\n")

      error = assert_raise MissingFieldError, fn -> Post.from_file(path, config) end
      assert error.field == :title
    end

    test "raises ArgumentError when the filename isn't date-prefixed", %{config: config} do
      dir = Path.join(System.tmp_dir!(), "grimoire_post_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "not-date-prefixed.md")
      File.write!(path, "---\ntitle: Oops\n---\nBody.\n")

      assert_raise ArgumentError, ~r/date-prefixed/, fn -> Post.from_file(path, config) end
    end
  end
end
