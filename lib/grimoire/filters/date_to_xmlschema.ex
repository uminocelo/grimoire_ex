defmodule Grimoire.Filters.DateToXmlschema do
  @moduledoc """
  `{{ post.date | date_to_xmlschema }}` → `"2024-01-05T00:00:00Z"`
  (RFC 3339 / ISO 8601), for RSS/Atom feed timestamps.
  """

  @behaviour Alembic.Filter

  alias Grimoire.Filters.Dates

  @doc "The template-facing filter name, `\"date_to_xmlschema\"`."
  @impl true
  @spec name() :: String.t()
  def name, do: "date_to_xmlschema"

  @doc "Formats `value` as RFC 3339 / ISO 8601 (`\"2024-01-05T00:00:00Z\"`)."
  @impl true
  @spec apply(Date.t() | DateTime.t() | String.t(), list()) ::
          {:ok, String.t()} | {:error, term()}
  def apply(value, _args) do
    with {:ok, date} <- Dates.parse(value) do
      {:ok, Date.to_iso8601(date) <> "T00:00:00Z"}
    end
  end
end
