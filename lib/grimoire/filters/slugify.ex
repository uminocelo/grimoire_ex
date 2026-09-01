defmodule Grimoire.Filters.Slugify do
  @moduledoc """
  `{{ "Elixir Tips" | slugify }}` → `"elixir-tips"`. Delegates to
  `Grimoire.Router.slugify/1`, which the Router also uses for tag/category
  URL segments.
  """

  @behaviour Alembic.Filter

  alias Grimoire.Router

  @impl true
  def name, do: "slugify"

  @impl true
  def apply(value, _args) when is_binary(value), do: {:ok, Router.slugify(value)}
end
