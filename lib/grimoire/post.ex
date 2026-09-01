defmodule Grimoire.Post do
  @moduledoc """
  A single blog post, parsed from a `_posts/YYYY-MM-DD-slug.md` file.

  `url`/`output_path` are computed via `Grimoire.Router`, which owns
  permalink pattern configuration — see `.plan/branches/1/milestones/3/3.3.md`.
  """

  alias Grimoire.{FrontMatter, Markdown, Router}
  alias Grimoire.FrontMatter.MissingFieldError

  defstruct [
    # From front matter
    :title,
    :date,
    :layout,
    :tags,
    :categories,
    :excerpt,
    :published,
    :permalink,

    # Derived from filename
    :slug,
    :source_path,

    # Generated
    :url,
    :output_path,
    :content_html,
    :raw_meta,
    :next,
    :previous
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          date: Date.t(),
          layout: String.t(),
          tags: [String.t()],
          categories: [String.t()],
          excerpt: String.t(),
          published: boolean(),
          permalink: String.t() | nil,
          slug: String.t(),
          source_path: String.t(),
          url: String.t(),
          output_path: String.t(),
          content_html: String.t(),
          raw_meta: map(),
          next: t() | nil,
          previous: t() | nil
        }

  @filename_re ~r/^(\d{4})-(\d{2})-(\d{2})-(.+)$/

  @doc """
  Builds a `%Post{}` from a `_posts/` source file.

  Raises `Grimoire.FrontMatter.MissingFieldError` if `title` is absent, and
  `ArgumentError` if the filename isn't date-prefixed
  (`YYYY-MM-DD-slug.md`). `date` is always derived from the filename, not
  from front matter — a redundant front matter `date:` field is ignored for
  this struct field but preserved in `raw_meta`.
  """
  @spec from_file(String.t(), Grimoire.Config.t()) :: t()
  def from_file(path, config) do
    {date, slug} = parse_filename(path)
    {meta, body} = path |> File.read!() |> FrontMatter.parse()

    unless is_binary(Map.get(meta, :title)), do: raise(MissingFieldError, field: :title)

    content_html = Markdown.to_html!(body)

    post = %__MODULE__{
      title: meta.title,
      date: date,
      layout: Map.get(meta, :layout, "post"),
      tags: Map.get(meta, :tags, []),
      categories: Map.get(meta, :categories, []),
      excerpt: excerpt(meta, content_html),
      published: Map.get(meta, :published, true),
      permalink: Map.get(meta, :permalink),
      slug: slug,
      source_path: path,
      content_html: content_html,
      raw_meta: meta
    }

    url = Router.post_url(post, config)
    %{post | url: url, output_path: Router.output_path(url, config)}
  end

  defp parse_filename(path) do
    basename = path |> Path.basename() |> String.replace_suffix(".md", "")

    case Regex.run(@filename_re, basename) do
      [_, y, m, d, slug] ->
        {Date.from_iso8601!("#{y}-#{m}-#{d}"), slug}

      nil ->
        raise ArgumentError,
              "post filename #{inspect(path)} must be date-prefixed (YYYY-MM-DD-slug.md)"
    end
  end

  defp excerpt(meta, content_html) do
    case Map.get(meta, :excerpt) do
      explicit when is_binary(explicit) -> explicit
      _ -> auto_excerpt(content_html)
    end
  end

  defp auto_excerpt(content_html) do
    case Regex.run(~r/<p>(.*?)<\/p>/s, content_html) do
      [_, text] -> text
      nil -> ""
    end
  end
end
