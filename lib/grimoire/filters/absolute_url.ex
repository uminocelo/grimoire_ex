defmodule Grimoire.Filters.AbsoluteUrl do
  @moduledoc """
  `{{ post.url | absolute_url }}` — prepends the site's full `base_url`
  (scheme, host, and any path prefix).
  """

  @behaviour Alembic.Filter

  alias Grimoire.Filters.UrlHelpers

  @doc "The template-facing filter name, `\"absolute_url\"`."
  @impl true
  @spec name() :: String.t()
  def name, do: "absolute_url"

  @doc "Prepends the site's full `base_url` to `value`."
  @impl true
  @spec apply(String.t(), list()) :: {:ok, String.t()}
  def apply(value, _args) when is_binary(value), do: {:ok, UrlHelpers.absolute(value)}
end
