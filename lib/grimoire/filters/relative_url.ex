defmodule Grimoire.Filters.RelativeUrl do
  @moduledoc """
  `{{ post.url | relative_url }}` — prepends the site's `base_url` path
  prefix (for sites hosted under a subpath, e.g. GitHub Pages project
  sites). A no-op when `base_url` has no path (or is `"/"`/empty).
  """

  @behaviour Alembic.Filter

  alias Grimoire.Filters.UrlHelpers

  @impl true
  def name, do: "relative_url"

  @impl true
  def apply(value, _args) when is_binary(value), do: {:ok, UrlHelpers.relative(value)}
end
