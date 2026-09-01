defmodule Grimoire.FiltersTest do
  use ExUnit.Case

  alias Grimoire.Filters.{
    AbsoluteUrl,
    DateToString,
    DateToXmlschema,
    RelativeUrl,
    Slugify,
    XmlEscape
  }

  describe "date_to_string" do
    test "name/0" do
      assert DateToString.name() == "date_to_string"
    end

    test "formats a Date.t() with the default format" do
      assert DateToString.apply(~D[2024-01-05], []) == {:ok, "January 5, 2024"}
    end

    test "accepts an ISO 8601 string" do
      assert DateToString.apply("2024-01-05", []) == {:ok, "January 5, 2024"}
    end

    test "honours an optional format-string argument" do
      assert DateToString.apply(~D[2024-01-05], ["%Y-%m-%d"]) == {:ok, "2024-01-05"}
    end
  end

  describe "date_to_xmlschema" do
    test "name/0" do
      assert DateToXmlschema.name() == "date_to_xmlschema"
    end

    test "formats as RFC 3339 / ISO 8601" do
      assert DateToXmlschema.apply(~D[2024-01-05], []) == {:ok, "2024-01-05T00:00:00Z"}
    end
  end

  describe "xml_escape" do
    test "name/0" do
      assert XmlEscape.name() == "xml_escape"
    end

    test "escapes &, <, >, and \"" do
      assert XmlEscape.apply(~s(Tom & Jerry <say> "hi"), []) ==
               {:ok, "Tom &amp; Jerry &lt;say&gt; &quot;hi&quot;"}
    end

    test "does not double-escape a fresh string" do
      assert XmlEscape.apply("plain text", []) == {:ok, "plain text"}
    end
  end

  describe "slugify" do
    test "name/0" do
      assert Slugify.name() == "slugify"
    end

    test "downcases, strips punctuation, and dash-separates" do
      assert Slugify.apply("Elixir Tips!", []) == {:ok, "elixir-tips"}
    end
  end

  describe "relative_url and absolute_url" do
    setup do
      previous = Application.get_env(:grimoire, :base_url)
      on_exit(fn -> Application.put_env(:grimoire, :base_url, previous) end)
    end

    test "relative_url/absolute_url name/0" do
      assert RelativeUrl.name() == "relative_url"
      assert AbsoluteUrl.name() == "absolute_url"
    end

    test "relative_url prepends the base_url path prefix" do
      Application.put_env(:grimoire, :base_url, "https://example.com/blog")
      assert RelativeUrl.apply("/posts/hello/", []) == {:ok, "/blog/posts/hello/"}
    end

    test "relative_url is a no-op when base_url has no path" do
      Application.put_env(:grimoire, :base_url, "https://example.com")
      assert RelativeUrl.apply("/posts/hello/", []) == {:ok, "/posts/hello/"}
    end

    test "relative_url is a no-op when base_url is \"/\" or empty" do
      Application.put_env(:grimoire, :base_url, "/")
      assert RelativeUrl.apply("/posts/hello/", []) == {:ok, "/posts/hello/"}

      Application.put_env(:grimoire, :base_url, "")
      assert RelativeUrl.apply("/posts/hello/", []) == {:ok, "/posts/hello/"}
    end

    test "absolute_url prepends scheme, host, and path prefix" do
      Application.put_env(:grimoire, :base_url, "https://example.com/blog")

      assert AbsoluteUrl.apply("/posts/hello/", []) ==
               {:ok, "https://example.com/blog/posts/hello/"}
    end

    test "end-to-end: a template piping through relative_url/absolute_url with a configured base_url" do
      Application.put_env(:grimoire, :base_url, "https://example.com/blog")

      assert {:ok, html} =
               Alembic.render_string(
                 "{{ url | relative_url }} | {{ url | absolute_url }}",
                 %{"url" => "/posts/hello/"}
               )

      assert html == "/blog/posts/hello/ | https://example.com/blog/posts/hello/"
    end
  end
end
