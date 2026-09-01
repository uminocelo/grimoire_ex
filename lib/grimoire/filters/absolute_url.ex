defmodule Grimoire.Filters.AbsoluteUrl do
  @moduledoc """
  `{{ post.url | absolute_url }}` — prepends the site's full `base_url`
  (scheme, host, and any path prefix).
  """

  @behaviour Alembic.Filter

  alias Grimoire.Filters.UrlHelpers

  @impl true
  def name, do: "absolute_url"

  @impl true
  def apply(value, _args) when is_binary(value), do: {:ok, UrlHelpers.absolute(value)}
end
