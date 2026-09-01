defmodule Grimoire.Page do
  @moduledoc """
  A single static page, parsed from a `_pages/slug.md` file.

  `url`/`output_path` are computed via `Grimoire.Router` — see
  `Grimoire.Post`'s moduledoc.
  """

  alias Grimoire.{FrontMatter, Markdown, Router}
  alias Grimoire.FrontMatter.MissingFieldError

  defstruct [
    :title,
    :layout,
    :permalink,
    :slug,
    :source_path,
    :url,
    :output_path,
    :content_html,
    :raw_meta
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          layout: String.t() | nil,
          permalink: String.t() | nil,
          slug: String.t(),
          source_path: String.t(),
          url: String.t() | nil,
          output_path: String.t() | nil,
          content_html: String.t(),
          raw_meta: map()
        }

  @doc """
  Builds a `%Page{}` from a `_pages/` source file.

  Raises `Grimoire.FrontMatter.MissingFieldError` if `title` is absent.
  `index.md` is special-cased to the site root URL `/`. An explicit
  `permalink:` front matter field overrides the default `/slug/` URL.
  """
  @spec from_file(String.t(), Grimoire.Config.t()) :: t()
  def from_file(path, config) do
    slug = path |> Path.basename() |> String.replace_suffix(".md", "")
    {meta, body} = path |> File.read!() |> FrontMatter.parse()

    unless is_binary(Map.get(meta, :title)), do: raise(MissingFieldError, field: :title)

    content_html = Markdown.to_html!(body)

    page = %__MODULE__{
      title: meta.title,
      layout: Map.get(meta, :layout, "page"),
      permalink: Map.get(meta, :permalink),
      slug: slug,
      source_path: path,
      content_html: content_html,
      raw_meta: meta
    }

    url = Router.page_url(page, config)
    %{page | url: url, output_path: Router.output_path(url, config)}
  end
end
