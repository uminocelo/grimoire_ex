defmodule Grimoire.Filters.Slugify do
  @moduledoc """
  `{{ "Elixir Tips" | slugify }}` → `"elixir-tips"`. Delegates to
  `Grimoire.Router.slugify/1`, which the Router also uses for tag/category
  URL segments.
  """

  @behaviour Alembic.Filter

  alias Grimoire.Router

  @doc "The template-facing filter name, `\"slugify\"`."
  @impl true
  @spec name() :: String.t()
  def name, do: "slugify"

  @doc "Downcases, strips punctuation, and dash-separates `value`."
  @impl true
  @spec apply(String.t(), list()) :: {:ok, String.t()}
  def apply(value, _args) when is_binary(value), do: {:ok, Router.slugify(value)}
end
