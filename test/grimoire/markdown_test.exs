defmodule Grimoire.MarkdownTest do
  use ExUnit.Case, async: true

  alias Grimoire.Markdown

  defp html!(md), do: Markdown.to_html!(md)

  describe "code block extraction (pass 2)" do
    test "fenced block with a language hint" do
      assert html!("```elixir\ndef foo, do: :bar\n```") ==
               ~s(<pre><code class="language-elixir">def foo, do: :bar</code></pre>)
    end

    test "fenced block without a language hint" do
      assert html!("```\nplain\n```") == ~s(<pre><code>plain</code></pre>)
    end

    test "4-space indented block" do
      assert html!("    line one\n    line two") ==
               "<pre><code>line one\nline two</code></pre>"
    end

    test "escapes HTML inside fenced code content" do
      assert html!("```\n<script>&</script>\n```") ==
               ~s(<pre><code>&lt;script&gt;&amp;&lt;/script&gt;</code></pre>)
    end

    test "content inside a code block is never inline-processed" do
      assert html!("```\n**not bold** *not italic*\n```") ==
               ~s(<pre><code>**not bold** *not italic*</code></pre>)
    end

    test "an unterminated fence does not crash — consumes to end of input" do
      assert html!("```elixir\nunterminated") ==
               ~s(<pre><code class="language-elixir">unterminated</code></pre>)
    end
  end

  describe "block elements (pass 3)" do
    test "ATX headings h1 through h6" do
      for level <- 1..6 do
        hashes = String.duplicate("#", level)
        assert html!("#{hashes} Text") == ~s(<h#{level} id="text">Text</h#{level}>)
      end
    end

    test "setext h1" do
      assert html!("Title\n=====\n\nBody") ==
               "<h1 id=\"title\">Title</h1>\n<p>Body</p>"
    end

    test "setext h2" do
      assert html!("Sub\n---\n\nBody") ==
               "<h2 id=\"sub\">Sub</h2>\n<p>Body</p>"
    end

    test "a horizontal rule is distinguished from a setext underline" do
      # Standalone --- with no preceding text line is an <hr>, not a heading.
      assert html!("---") == "<hr>"
      assert html!("***") == "<hr>"
      assert html!("___") == "<hr>"
    end

    test "setext underline directly under text still resolves to a heading, not an hr" do
      assert html!("Heading Text\n---") == "<h2 id=\"heading-text\">Heading Text</h2>"
    end

    test "blockquote, single paragraph" do
      assert html!("> line one\n> line two") ==
               "<blockquote>\n<p>line one\nline two</p>\n</blockquote>"
    end

    test "unordered list" do
      assert html!("- a\n- b\n- c") ==
               "<ul>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ul>"
    end

    test "ordered list" do
      assert html!("1. a\n2. b\n3. c") ==
               "<ol>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ol>"
    end

    test "nested unordered list, 2 levels deep" do
      html = html!("- a\n  - nested1\n  - nested2\n- b")

      assert html == """
             <ul>
             <li>a
             <ul>
             <li>nested1</li>
             <li>nested2</li>
             </ul></li>
             <li>b</li>
             </ul>\
             """
    end

    test "raw HTML passthrough is preserved as-is, not wrapped in <p>" do
      assert html!(~s(<div class="custom">raw html</div>)) ==
               ~s(<div class="custom">raw html</div>)
    end

    test "paragraphs separated by a blank line" do
      assert html!("First paragraph.\n\nSecond paragraph.") ==
               "<p>First paragraph.</p>\n<p>Second paragraph.</p>"
    end

    test "a heading immediately followed by a paragraph with no blank line still splits correctly" do
      assert html!("# Heading\nParagraph right after") ==
               "<h1 id=\"heading\">Heading</h1>\n<p>Paragraph right after</p>"
    end
  end

  describe "inline elements (pass 4)" do
    test "inline code, with inner HTML escaped" do
      assert html!("`<tag> & co`") == "<p><code>&lt;tag&gt; &amp; co</code></p>"
    end

    test "images" do
      assert html!("![alt](http://example.com/img.png)") ==
               ~s(<p><img src="http://example.com/img.png" alt="alt"></p>)
    end

    test "images with a title" do
      assert html!(~s{![alt](http://x/img.png "a title")}) ==
               ~s(<p><img src="http://x/img.png" alt="alt" title="a title"></p>)
    end

    test "links" do
      assert html!("[text](http://example.com)") ==
               ~s(<p><a href="http://example.com">text</a></p>)
    end

    test "links with a title" do
      assert html!(~s{[text](http://x "a title")}) ==
               ~s(<p><a href="http://x" title="a title">text</a></p>)
    end

    test "bold+italic, bold, italic" do
      assert html!("***both***") == "<p><strong><em>both</em></strong></p>"
      assert html!("**bold**") == "<p><strong>bold</strong></p>"
      assert html!("__bold__") == "<p><strong>bold</strong></p>"
      assert html!("*italic*") == "<p><em>italic</em></p>"
    end

    test "underscore italic is word-boundary aware" do
      assert html!("_italic_") == "<p><em>italic</em></p>"
      assert html!("snake_case_word") == "<p>snake_case_word</p>"
    end

    test "strikethrough" do
      assert html!("~~gone~~") == "<p><del>gone</del></p>"
    end

    test "bare autolinks" do
      assert html!("visit https://example.com now") ==
               ~s(<p>visit <a href="https://example.com">https://example.com</a> now</p>)
    end

    test "hard line break on 2+ trailing spaces" do
      assert html!("line one  \nline two") == "<p>line one<br>\nline two</p>"
    end

    test "bare ampersands are escaped, already-escaped entities are not double-escaped" do
      assert html!("Fish & Chips") == "<p>Fish &amp; Chips</p>"
    end

    test "applying rules in order does not corrupt bold text inside a link" do
      assert html!("[**bold link**](http://x)") ==
               ~s(<p><a href="http://x"><strong>bold link</strong></a></p>)
    end
  end

  describe "heading IDs and de-duplication" do
    test "duplicate heading text gets distinct, deterministic ids" do
      assert html!("# Dup\n\n# Dup\n\n# Dup") ==
               "<h1 id=\"dup\">Dup</h1>\n<h1 id=\"dup-1\">Dup</h1>\n<h1 id=\"dup-2\">Dup</h1>"
    end
  end

  describe "toc/1" do
    test "returns {level, text, anchor} tuples in document order with matching anchors" do
      md = "# One\n\nBody\n\n## Two\n\nMore\n\n# One"

      assert Markdown.toc(md) == [
               {1, "One", "one"},
               {2, "Two", "two"},
               {1, "One", "one-1"}
             ]
    end
  end

  describe "edge cases" do
    test "empty input" do
      assert html!("") == ""
    end

    test "whitespace-only input" do
      assert html!("   \n\n\t \n") == ""
    end

    test "to_html/1 never raises, wrapping errors instead" do
      assert {:ok, _html} = Markdown.to_html("# fine")
    end

    test "any run of blank lines between blocks normalizes to a single newline" do
      one_blank = html!("First.\n\nSecond.")
      five_blanks = html!("First.\n\n\n\n\nSecond.")

      assert one_blank == "<p>First.</p>\n<p>Second.</p>"
      assert five_blanks == one_blank
    end
  end

  describe "integration — full document" do
    test "a representative post body renders as expected" do
      md = """
      # My Post

      Some *intro* text with a [link](http://example.com) and `code`.

      ## Section

      - one
      - two
        - nested

      > A quote.

      ```elixir
      IO.puts("hi")
      ```

      The end.
      """

      html = html!(md)

      assert html =~ "<h1 id=\"my-post\">My Post</h1>"
      assert html =~ "<em>intro</em>"
      assert html =~ ~s(<a href="http://example.com">link</a>)
      assert html =~ "<code>code</code>"
      assert html =~ "<h2 id=\"section\">Section</h2>"
      assert html =~ "<li>one</li>"
      assert html =~ "<li>two\n<ul>\n<li>nested</li>\n</ul></li>"
      assert html =~ "<blockquote>\n<p>A quote.</p>\n</blockquote>"
      assert html =~ ~s{<pre><code class="language-elixir">IO.puts("hi")}
      assert html =~ "<p>The end.</p>"
    end
  end
end
