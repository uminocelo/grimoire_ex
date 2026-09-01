defmodule Grimoire.Site do
  @moduledoc """
  The fully scanned representation of a Grimoire site: config plus every
  discovered post, page, asset, tag, and category. Built by
  `Grimoire.Scanner.scan/1` and consumed by the Renderer and Builder.

  `root` is the site source directory passed to `scan/1` — the Renderer
  uses it to configure Alembic's `_layouts/`/`_includes/` template roots.
  """

  defstruct [:config, :root, posts: [], pages: [], assets: [], tags: %{}, categories: %{}]

  @type t :: %__MODULE__{
          config: Grimoire.Config.t() | nil,
          root: String.t() | nil,
          posts: list(),
          pages: list(),
          assets: list(),
          tags: %{optional(String.t()) => list()},
          categories: %{optional(String.t()) => list()}
        }
end
