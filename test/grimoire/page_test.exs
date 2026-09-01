defmodule Grimoire.PageTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Config, Page}
  alias Grimoire.FrontMatter.MissingFieldError
  import Grimoire.Test.Fixtures

  setup do
    %{config: Config.load(site_path("content_site"))}
  end

  describe "from_file/2" do
    test "populates every struct field correctly", %{config: config} do
      path = Path.join(site_path("content_site"), "_pages/about.md")
      page = Page.from_file(path, config)

      assert page.title == "About"
      assert page.slug == "about"
      assert page.source_path == path
      assert page.url == "/about/"
      assert page.output_path == "_site/about/index.html"
      assert page.content_html =~ "About this fixture site."
      assert page.permalink == nil
    end

    test "defaults layout to \"page\" when absent from front matter", %{config: config} do
      path = Path.join(site_path("content_site"), "_pages/about.md")
      page = Page.from_file(path, config)

      assert page.layout == "page"
    end

    test "index.md is special-cased to the site root URL", %{config: config} do
      path = Path.join(site_path("content_site"), "_pages/index.md")
      page = Page.from_file(path, config)

      assert page.url == "/"
      assert page.output_path == "_site/index.html"
    end

    test "an explicit permalink: front matter field overrides the default URL", %{config: config} do
      path = Path.join(site_path("content_site"), "_pages/contact.md")
      page = Page.from_file(path, config)

      assert page.permalink == "/contact-us/"
      assert page.url == "/contact-us/"
      assert page.output_path == "_site/contact-us/index.html"
    end

    test "raises MissingFieldError naming :title when front matter has no title", %{
      config: config
    } do
      dir = Path.join(System.tmp_dir!(), "grimoire_page_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      path = Path.join(dir, "no-title.md")
      File.write!(path, "Body only, no front matter.\n")

      error = assert_raise MissingFieldError, fn -> Page.from_file(path, config) end
      assert error.field == :title
    end
  end
end
