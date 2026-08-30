defmodule Grimoire.Site do
  @moduledoc """
  The fully scanned representation of a Grimoire site: config plus every
  discovered post, page, asset, tag, and category. Built by
  `Grimoire.Scanner.scan/1` and consumed by the Renderer and Builder.
  """

  defstruct [:config, posts: [], pages: [], assets: [], tags: %{}, categories: %{}]

  @type t :: %__MODULE__{
          config: Grimoire.Config.t() | nil,
          posts: list(),
          pages: list(),
          assets: list(),
          tags: %{optional(String.t()) => list()},
          categories: %{optional(String.t()) => list()}
        }
end
