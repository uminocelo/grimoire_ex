defmodule Grimoire.Filters.DateToXmlschema do
  @moduledoc """
  `{{ post.date | date_to_xmlschema }}` → `"2024-01-05T00:00:00Z"`
  (RFC 3339 / ISO 8601), for RSS/Atom feed timestamps.
  """

  @behaviour Alembic.Filter

  alias Grimoire.Filters.Dates

  @impl true
  def name, do: "date_to_xmlschema"

  @impl true
  def apply(value, _args) do
    with {:ok, date} <- Dates.parse(value) do
      {:ok, Date.to_iso8601(date) <> "T00:00:00Z"}
    end
  end
end
