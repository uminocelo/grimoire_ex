defmodule Grimoire.FrontMatterTest do
  use ExUnit.Case, async: true

  alias Grimoire.FrontMatter
  alias Grimoire.FrontMatter.MissingFieldError

  describe "parse/1 — block extraction" do
    test "splits a well-formed front matter block from the body" do
      content = """
      ---
      title: Hello Grimoire
      ---

      # Hello, world!
      """

      assert {%{title: "Hello Grimoire"}, body} = FrontMatter.parse(content)
      assert body == "\n# Hello, world!\n"
    end

    test "returns {%{}, content} unchanged for a file with no front matter" do
      content = "# Just a heading\n\nSome body text.\n"

      assert FrontMatter.parse(content) == {%{}, content}
    end

    test "returns {%{}, body} for an empty front matter block" do
      content = "---\n---\n\nBody only.\n"

      assert FrontMatter.parse(content) == {%{}, "\nBody only.\n"}
    end

    test "does not split further on dashes appearing inside the body" do
      content = """
      ---
      title: Has a rule
      ---

      Above the rule.

      ---

      Below the rule.
      """

      assert {%{title: "Has a rule"}, body} = FrontMatter.parse(content)
      assert body =~ "Above the rule."
      assert body =~ "---"
      assert body =~ "Below the rule."
    end

    test "front-matter-only file (empty body)" do
      content = "---\ntitle: Only Meta\n---\n"

      assert FrontMatter.parse(content) == {%{title: "Only Meta"}, ""}
    end
  end

  describe "parse/1 — value coercion" do
    test "parses all five documented value types" do
      content = """
      ---
      title: Hello Grimoire
      count: 42
      published: true
      date: 2024-01-15
      tags:
        - elixir
        - tutorial
      ---
      Body.
      """

      {meta, _body} = FrontMatter.parse(content)

      assert meta.title == "Hello Grimoire"
      # "count" isn't a known key, so it's kept under a string key (see
      # moduledoc), but its *value* is still coerced to an integer either way.
      assert meta["count"] == 42
      assert meta.published == true
      assert meta.date == ~D[2024-01-15]
      assert meta.tags == ["elixir", "tutorial"]
    end

    test "boolean false coerces correctly" do
      content = "---\npublished: false\n---\nBody.\n"

      assert {%{published: false}, _} = FrontMatter.parse(content)
    end
  end

  describe "parse/1 — list values" do
    test "a list key immediately followed by a non-list-item line yields an empty list" do
      content = """
      ---
      tags:
      title: No Items
      ---
      Body.
      """

      {meta, _body} = FrontMatter.parse(content)

      assert meta.tags == []
      assert meta.title == "No Items"
    end
  end

  describe "unrecognized keys" do
    test "unknown keys are kept as string keys, not dropped" do
      content = "---\ntitle: Known\ncustom_field: keep me\n---\nBody.\n"

      {meta, _body} = FrontMatter.parse(content)

      assert meta.title == "Known"
      assert meta["custom_field"] == "keep me"
    end
  end

  describe "validate_post!/1" do
    test "passes with title and date present" do
      assert :ok = FrontMatter.validate_post!(%{title: "Hi", date: ~D[2024-01-01]})
    end

    test "raises MissingFieldError naming :title when title is absent" do
      error =
        assert_raise MissingFieldError, fn ->
          FrontMatter.validate_post!(%{date: ~D[2024-01-01]})
        end

      assert error.field == :title
      assert Exception.message(error) =~ ":title"
    end

    test "raises MissingFieldError naming :date when date is absent" do
      error = assert_raise MissingFieldError, fn -> FrontMatter.validate_post!(%{title: "Hi"}) end
      assert error.field == :date
      assert Exception.message(error) =~ ":date"
    end
  end

  describe "validate_page!/1" do
    test "passes with title present" do
      assert :ok = FrontMatter.validate_page!(%{title: "About"})
    end

    test "raises MissingFieldError naming :title when title is absent" do
      error = assert_raise MissingFieldError, fn -> FrontMatter.validate_page!(%{}) end
      assert error.field == :title
    end
  end
end
