defmodule Grimoire.Filters.XmlEscape do
  @moduledoc """
  `{{ post.title | xml_escape }}` — escapes `&`, `<`, `>`, and `"` for safe
  inclusion in XML (feed titles, attribute values).
  """

  @behaviour Alembic.Filter

  @doc "The template-facing filter name, `\"xml_escape\"`."
  @impl true
  @spec name() :: String.t()
  def name, do: "xml_escape"

  @doc "Escapes `&`, `<`, `>`, and `\"` in `value` for safe inclusion in XML."
  @impl true
  @spec apply(String.t(), list()) :: {:ok, String.t()}
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
