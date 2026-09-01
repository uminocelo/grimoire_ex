defmodule Grimoire.Filters.XmlEscape do
  @moduledoc """
  `{{ post.title | xml_escape }}` — escapes `&`, `<`, `>`, and `"` for safe
  inclusion in XML (feed titles, attribute values).
  """

  @behaviour Alembic.Filter

  @impl true
  def name, do: "xml_escape"

  @impl true
  def apply(value, _args) when is_binary(value) do
    escaped =
      value
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace("\"", "&quot;")

    {:ok, escaped}
  end
end
