defmodule Grimoire.Markdown do
  @moduledoc """
  A multi-pass Markdown-to-HTML converter for the subset of Markdown a blog
  SSG needs. No external dependency.

  Markdown is not a context-free grammar — the interaction between block
  and inline elements, and context-sensitive rules like setext headings,
  make a single-pass parser impractical. This module runs sequential
  passes over the document, each responsible for one category of element:

  1. **Code extraction** — fenced/indented code blocks (and inline code
     spans) are pulled out and replaced with placeholder tokens, so no
     later pass can mangle their content.
  2. **Block structure** — headings, horizontal rules, blockquotes, lists,
     raw HTML passthrough, paragraphs.
  3. **Inline elements** — bold, italic, links, images, etc., applied to
     each block's text as it's built.
  4. **Cleanup** — code blocks restored, blank-line runs collapsed,
     surrounding whitespace trimmed.

  This is a pragmatic, regex-and-line-scan based implementation, not a
  CommonMark-conformant parser — see `docs/` for known limitations.
  """

  @code_block_token "\x00CODE_BLOCK_"
  @inline_code_token "\x01INLINE_CODE_"

  @doc """
  Converts `markdown` to HTML. Never raises — returns `{:error, reason}`
  instead.
  """
  @spec to_html(String.t()) :: {:ok, String.t()} | {:error, term()}
  def to_html(markdown) when is_binary(markdown) do
    {:ok, to_html!(markdown)}
  rescue
    e -> {:error, e}
  end

  @doc "Same as `to_html/1`, raising on error."
  @spec to_html!(String.t()) :: String.t()
  def to_html!(markdown) when is_binary(markdown) do
    {source, code_blocks} = extract_code_blocks(markdown)
    lines = String.split(source, "\n")
    heading_queue = lines |> find_headings() |> slugify_headings()

    {html_lines, _remaining} = blocks_to_html(lines, [], heading_queue)

    html_lines
    |> Enum.reverse()
    |> Enum.join("\n")
    |> restore_code_blocks(code_blocks)
    |> cleanup()
  end

  @doc """
  Returns `{level, text, anchor}` tuples for every heading in `markdown`,
  in document order, with the same anchors `to_html!/1` assigns.
  """
  @spec toc(String.t()) :: [{pos_integer(), String.t(), String.t()}]
  def toc(markdown) when is_binary(markdown) do
    {source, _code_blocks} = extract_code_blocks(markdown)

    source
    |> String.split("\n")
    |> find_headings()
    |> slugify_headings()
  end

  # -- Pass: code extraction -------------------------------------------

  @fence_re ~r/^(```|~~~)\s*([\w-]*)\s*$/

  defp extract_code_blocks(markdown) do
    lines = String.split(markdown, "\n")
    {out_lines, blocks} = extract_code_blocks(lines, [], [], 0)
    {Enum.join(Enum.reverse(out_lines), "\n"), Enum.reverse(blocks)}
  end

  defp extract_code_blocks([], out, blocks, _n), do: {out, blocks}

  defp extract_code_blocks([line | rest], out, blocks, n) do
    cond do
      match = Regex.run(@fence_re, line) ->
        [_, fence, lang] = match
        {content, remaining} = take_fenced(rest, fence)
        html = code_block_html(Enum.join(content, "\n"), lang)
        token = placeholder(@code_block_token, n)
        extract_code_blocks(remaining, [token | out], [html | blocks], n + 1)

      indented_code_line?(line) ->
        {content, remaining} = take_indented([line | rest])
        html = code_block_html(Enum.join(content, "\n"), "")
        token = placeholder(@code_block_token, n)
        extract_code_blocks(remaining, [token | out], [html | blocks], n + 1)

      true ->
        extract_code_blocks(rest, [line | out], blocks, n)
    end
  end

  defp take_fenced([], _fence), do: {[], []}

  defp take_fenced([line | rest], fence) do
    if String.trim(line) == fence do
      {[], rest}
    else
      {content, remaining} = take_fenced(rest, fence)
      {[line | content], remaining}
    end
  end

  defp indented_code_line?(line), do: String.starts_with?(line, "    ")

  defp take_indented(lines), do: take_indented(lines, [])

  defp take_indented([line | rest], acc) do
    if indented_code_line?(line) do
      take_indented(rest, [String.replace_prefix(line, "    ", "") | acc])
    else
      {Enum.reverse(acc), [line | rest]}
    end
  end

  defp take_indented([], acc), do: {Enum.reverse(acc), []}

  defp code_block_html(content, "") do
    "<pre><code>#{escape_html(content)}</code></pre>"
  end

  defp code_block_html(content, lang) do
    "<pre><code class=\"language-#{lang}\">#{escape_html(content)}</code></pre>"
  end

  defp placeholder(prefix, n), do: "#{prefix}#{n}\x00"

  defp restore_code_blocks(html, blocks) do
    blocks
    |> Enum.with_index()
    |> Enum.reduce(html, fn {block_html, n}, acc ->
      String.replace(acc, placeholder(@code_block_token, n), block_html)
    end)
  end

  # -- Heading detection (shared by the block scanner and toc/1) -------

  @atx_re ~r/^(\#{1,6})\s+(.+?)\s*\#*\s*$/
  @hr_re ~r/^ {0,3}([-*_])(?: *\1){2,} *$/
  @setext_1_re ~r/^=+\s*$/
  @setext_2_re ~r/^-+\s*$/
  @ul_re ~r/^(\s*)[-*+]\s+(.+)$/
  @ol_re ~r/^(\s*)\d+\.\s+(.+)$/
  @blockquote_re ~r/^\s*>\s?(.*)$/

  defp atx_heading(line) do
    case Regex.run(@atx_re, line) do
      [_, hashes, text] -> {String.length(hashes), text}
      nil -> nil
    end
  end

  defp plain_text_line?(line) do
    trimmed = String.trim(line)

    trimmed != "" and
      is_nil(atx_heading(line)) and
      not Regex.match?(@hr_re, line) and
      not Regex.match?(@blockquote_re, line) and
      not Regex.match?(@ul_re, line) and
      not Regex.match?(@ol_re, line) and
      not String.starts_with?(trimmed, "<")
  end

  defp find_headings([]), do: []

  defp find_headings([line, next | rest]) do
    cond do
      atx = atx_heading(line) ->
        [atx | find_headings([next | rest])]

      plain_text_line?(line) and Regex.match?(@setext_1_re, next) ->
        [{1, String.trim(line)} | find_headings(rest)]

      plain_text_line?(line) and Regex.match?(@setext_2_re, next) ->
        [{2, String.trim(line)} | find_headings(rest)]

      true ->
        find_headings([next | rest])
    end
  end

  defp find_headings([line]) do
    case atx_heading(line) do
      nil -> []
      heading -> [heading]
    end
  end

  defp slugify_headings(headings) do
    {result, _seen} =
      Enum.map_reduce(headings, %{}, fn {level, text}, seen ->
        base = slugify(text)
        count = Map.get(seen, base, 0)
        anchor = if count == 0, do: base, else: "#{base}-#{count}"
        {{level, text, anchor}, Map.put(seen, base, count + 1)}
      end)

    result
  end

  defp slugify(text) do
    text
    |> strip_inline_markup()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end

  defp strip_inline_markup(text), do: Regex.replace(~r/[*_`~\[\]()]/, text, "")

  # -- Pass: block structure --------------------------------------------

  defp blocks_to_html([], acc, headings), do: {acc, headings}

  defp blocks_to_html([line | rest] = lines, acc, headings) do
    cond do
      String.trim(line) == "" ->
        blocks_to_html(rest, acc, headings)

      match = code_placeholder_line(line) ->
        blocks_to_html(rest, [match | acc], headings)

      setext = setext_block(lines) ->
        {{level, _text}, remaining} = setext
        [{^level, _text, anchor} | headings_rest] = headings
        html = heading_html(level, inline(String.trim(line)), anchor)
        blocks_to_html(remaining, [html | acc], headings_rest)

      atx_heading(line) ->
        {level, text} = atx_heading(line)
        [{^level, ^text, anchor} | headings_rest] = headings
        blocks_to_html(rest, [heading_html(level, inline(text), anchor) | acc], headings_rest)

      Regex.match?(@hr_re, line) ->
        blocks_to_html(rest, ["<hr>" | acc], headings)

      Regex.match?(@blockquote_re, line) ->
        {quote_lines, remaining} = take_blockquote(lines)
        html = blockquote_html(quote_lines)
        blocks_to_html(remaining, [html | acc], headings)

      Regex.match?(@ul_re, line) ->
        {items, remaining} = take_list(lines, @ul_re)
        html = "<ul>\n" <> Enum.map_join(items, "\n", &list_item_html/1) <> "\n</ul>"
        blocks_to_html(remaining, [html | acc], headings)

      Regex.match?(@ol_re, line) ->
        {items, remaining} = take_list(lines, @ol_re)
        html = "<ol>\n" <> Enum.map_join(items, "\n", &list_item_html/1) <> "\n</ol>"
        blocks_to_html(remaining, [html | acc], headings)

      String.starts_with?(String.trim_leading(line), "<") ->
        {raw_lines, remaining} = take_while_nonblank(lines)
        blocks_to_html(remaining, [Enum.join(raw_lines, "\n") | acc], headings)

      true ->
        {para_lines, remaining} = take_paragraph(lines)
        html = "<p>" <> inline(Enum.join(para_lines, "\n")) <> "</p>"
        blocks_to_html(remaining, [html | acc], headings)
    end
  end

  defp code_placeholder_line(line) do
    if String.starts_with?(String.trim(line), @code_block_token) and
         String.ends_with?(String.trim(line), "\x00") do
      String.trim(line)
    else
      nil
    end
  end

  defp setext_block([line, next | rest]) do
    cond do
      plain_text_line?(line) and Regex.match?(@setext_1_re, next) -> {{1, line}, rest}
      plain_text_line?(line) and Regex.match?(@setext_2_re, next) -> {{2, line}, rest}
      true -> nil
    end
  end

  defp setext_block(_), do: nil

  defp heading_html(level, text, anchor) do
    "<h#{level} id=\"#{anchor}\">#{text}</h#{level}>"
  end

  # -- Blockquotes --------------------------------------------------------

  defp take_blockquote(lines), do: take_blockquote(lines, [])

  defp take_blockquote([line | rest], acc) do
    cond do
      Regex.match?(@blockquote_re, line) ->
        [_, content] = Regex.run(@blockquote_re, line)
        take_blockquote(rest, [content | acc])

      String.trim(line) == "" ->
        {Enum.reverse(acc), rest}

      true ->
        {Enum.reverse(acc), [line | rest]}
    end
  end

  defp take_blockquote([], acc), do: {Enum.reverse(acc), []}

  defp blockquote_html(lines) do
    paragraphs =
      lines
      |> Enum.join("\n")
      |> String.split(~r/\n\s*\n/)
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map_join("\n", &("<p>" <> inline(String.trim(&1)) <> "</p>"))

    "<blockquote>\n#{paragraphs}\n</blockquote>"
  end

  # -- Lists ----------------------------------------------------------

  defp take_list(lines, marker_re), do: take_list(lines, marker_re, [])

  defp take_list([line | rest] = lines, marker_re, acc) do
    cond do
      Regex.match?(marker_re, line) and indent_of(line) == 0 ->
        {item_lines, remaining} = take_item_block(rest)
        take_list(remaining, marker_re, [[line | item_lines] | acc])

      String.trim(line) == "" ->
        {Enum.reverse(acc), rest}

      true ->
        {Enum.reverse(acc), lines}
    end
  end

  defp take_list([], _marker_re, acc), do: {Enum.reverse(acc), []}

  # Lines belonging to the current item: indented (nested list or
  # continuation) lines, stopping at the next top-level marker, a blank
  # line, or a line back at column 0 that isn't part of this item.
  defp take_item_block(lines), do: take_item_block(lines, [])

  defp take_item_block([line | rest], acc) do
    cond do
      String.trim(line) == "" ->
        {Enum.reverse(acc), rest}

      indent_of(line) > 0 ->
        take_item_block(rest, [line | acc])

      true ->
        {Enum.reverse(acc), [line | rest]}
    end
  end

  defp take_item_block([], acc), do: {Enum.reverse(acc), []}

  defp indent_of(line) do
    String.length(line) - String.length(String.trim_leading(line))
  end

  defp list_item_html([first | nested]) do
    {_, text} = list_marker_text(first)
    nested_html = nested_content_html(nested)
    "<li>" <> inline(text) <> nested_html <> "</li>"
  end

  defp list_marker_text(line) do
    case Regex.run(@ul_re, line) || Regex.run(@ol_re, line) do
      [_, indent, text] -> {String.length(indent), text}
    end
  end

  defp nested_content_html([]), do: ""

  defp nested_content_html(lines) do
    dedented = dedent(lines)
    first = List.first(dedented)

    cond do
      Regex.match?(@ul_re, first) ->
        {items, _rest} = take_list(dedented, @ul_re)
        "\n<ul>\n" <> Enum.map_join(items, "\n", &list_item_html/1) <> "\n</ul>"

      Regex.match?(@ol_re, first) ->
        {items, _rest} = take_list(dedented, @ol_re)
        "\n<ol>\n" <> Enum.map_join(items, "\n", &list_item_html/1) <> "\n</ol>"

      true ->
        " " <> inline(Enum.join(dedented, " "))
    end
  end

  defp dedent(lines) do
    min_indent = lines |> Enum.map(&indent_of/1) |> Enum.min()
    Enum.map(lines, &String.slice(&1, min_indent..-1//1))
  end

  # -- Paragraphs / raw HTML -------------------------------------------

  defp take_while_nonblank(lines), do: take_while_nonblank(lines, [])

  defp take_while_nonblank([line | rest], acc) do
    if String.trim(line) == "" do
      {Enum.reverse(acc), rest}
    else
      take_while_nonblank(rest, [line | acc])
    end
  end

  defp take_while_nonblank([], acc), do: {Enum.reverse(acc), []}

  defp take_paragraph(lines), do: take_paragraph(lines, [])

  defp take_paragraph([line | rest] = lines, acc) do
    cond do
      String.trim(line) == "" ->
        {Enum.reverse(acc), rest}

      acc != [] and starts_new_block?(line) ->
        {Enum.reverse(acc), lines}

      true ->
        take_paragraph(rest, [line | acc])
    end
  end

  defp take_paragraph([], acc), do: {Enum.reverse(acc), []}

  defp starts_new_block?(line) do
    not is_nil(atx_heading(line)) or
      Regex.match?(@hr_re, line) or
      Regex.match?(@blockquote_re, line) or
      Regex.match?(@ul_re, line) or
      Regex.match?(@ol_re, line) or
      String.starts_with?(String.trim_leading(line), "<") or
      (String.starts_with?(String.trim(line), @code_block_token) and
         String.ends_with?(String.trim(line), "\x00"))
  end

  # -- Pass: inline elements --------------------------------------------

  defp inline(text) do
    {protected, inline_codes} = extract_inline_code(text)

    protected
    |> process_images()
    |> process_links()
    |> process_bold_italic()
    |> process_bold()
    |> process_italic()
    |> process_strikethrough()
    |> process_autolinks()
    |> process_hard_breaks()
    |> escape_ampersands()
    |> restore_inline_code(inline_codes)
  end

  @inline_code_re ~r/`([^`]+)`/

  defp extract_inline_code(text) do
    {text, codes} =
      Regex.scan(@inline_code_re, text)
      |> Enum.with_index()
      |> Enum.reduce({text, []}, fn {[whole, code], n}, {acc_text, acc_codes} ->
        token = placeholder(@inline_code_token, n)
        html = "<code>#{escape_html(code)}</code>"
        {String.replace(acc_text, whole, token, global: false), [html | acc_codes]}
      end)

    {text, Enum.reverse(codes)}
  end

  defp restore_inline_code(text, codes) do
    codes
    |> Enum.with_index()
    |> Enum.reduce(text, fn {html, n}, acc ->
      String.replace(acc, placeholder(@inline_code_token, n), html)
    end)
  end

  @image_re ~r/!\[([^\]]*)\]\(([^\s)]+)(?:\s+"([^"]*)")?\)/
  @link_re ~r/\[([^\]]+)\]\(([^\s)]+)(?:\s+"([^"]*)")?\)/
  @bold_italic_re ~r/\*\*\*(.+?)\*\*\*/
  @bold_star_re ~r/\*\*(.+?)\*\*/
  @bold_underscore_re ~r/__(.+?)__/
  @italic_star_re ~r/\*(.+?)\*/
  @italic_underscore_re ~r/(?<![a-zA-Z0-9])_([^_]+?)_(?![a-zA-Z0-9])/
  @strikethrough_re ~r/~~(.+?)~~/
  @autolink_re ~r/(?<!["'(>])(https?:\/\/[^\s<>"')]+)/
  @hard_break_re ~r/ {2,}\n/

  defp process_images(text) do
    Regex.replace(@image_re, text, fn _, alt, url, title ->
      title_attr = if title != "", do: " title=\"#{title}\"", else: ""
      "<img src=\"#{url}\" alt=\"#{alt}\"#{title_attr}>"
    end)
  end

  defp process_links(text) do
    Regex.replace(@link_re, text, fn _, link_text, url, title ->
      title_attr = if title != "", do: " title=\"#{title}\"", else: ""
      "<a href=\"#{url}\"#{title_attr}>#{link_text}</a>"
    end)
  end

  defp process_bold_italic(text),
    do: Regex.replace(@bold_italic_re, text, "<strong><em>\\1</em></strong>")

  defp process_bold(text) do
    text
    |> then(&Regex.replace(@bold_star_re, &1, "<strong>\\1</strong>"))
    |> then(&Regex.replace(@bold_underscore_re, &1, "<strong>\\1</strong>"))
  end

  defp process_italic(text) do
    text
    |> then(&Regex.replace(@italic_star_re, &1, "<em>\\1</em>"))
    |> then(&Regex.replace(@italic_underscore_re, &1, "<em>\\1</em>"))
  end

  defp process_strikethrough(text), do: Regex.replace(@strikethrough_re, text, "<del>\\1</del>")

  defp process_autolinks(text) do
    Regex.replace(@autolink_re, text, fn url -> "<a href=\"#{url}\">#{url}</a>" end)
  end

  defp process_hard_breaks(text), do: Regex.replace(@hard_break_re, text, "<br>\n")

  defp escape_ampersands(text) do
    Regex.replace(~r/&(?!(?:amp|lt|gt|quot|#\d+|#x[0-9a-fA-F]+);)/, text, "&amp;")
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  # -- Pass: cleanup ------------------------------------------------------

  defp cleanup(html) do
    html
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
