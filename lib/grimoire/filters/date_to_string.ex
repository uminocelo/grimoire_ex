defmodule Grimoire.Filters.DateToString do
  @moduledoc """
  `{{ post.date | date_to_string }}` → `"January 5, 2024"`.

  Accepts a `Date.t()`, a `DateTime.t()`, or an ISO 8601 date/datetime
  string. An optional first arg is a `Calendar.strftime/2` format string,
  overriding the default `"%B %-d, %Y"`.
  """

  @behaviour Alembic.Filter

  alias Grimoire.Filters.Dates

  @default_format "%B %-d, %Y"

  @impl true
  def name, do: "date_to_string"

  @impl true
  def apply(value, args) do
    with {:ok, date} <- Dates.parse(value) do
      {:ok, Calendar.strftime(date, format_arg(args))}
    end
  end

  defp format_arg([format | _]) when is_binary(format), do: format
  defp format_arg(_args), do: @default_format
end
