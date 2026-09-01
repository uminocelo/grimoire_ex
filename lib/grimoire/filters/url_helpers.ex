defmodule Grimoire.Filters.UrlHelpers do
  @moduledoc """
  Backs `relative_url`/`absolute_url`. Alembic filters only receive
  `(value, args)` — no template context — so `Grimoire.Renderer` publishes
  the active site's `base_url` via `Application.put_env(:grimoire,
  :base_url, ...)` before every render, and these helpers read it back
  from there.
  """

  @spec relative(String.t()) :: String.t()
  def relative(value) do
    case base_path() do
      "" -> value
      prefix -> String.trim_trailing(prefix, "/") <> ensure_leading_slash(value)
    end
  end

  @spec absolute(String.t()) :: String.t()
  def absolute(value) do
    case Application.get_env(:grimoire, :base_url) do
      base_url when is_binary(base_url) and base_url not in ["", "/"] ->
        origin(base_url) <> relative(value)

      _no_base_url ->
        value
    end
  end

  defp base_path do
    case Application.get_env(:grimoire, :base_url) do
      base_url when is_binary(base_url) and base_url not in ["", "/"] ->
        case URI.parse(base_url).path do
          nil -> ""
          "/" -> ""
          path -> path
        end

      _no_base_url ->
        ""
    end
  end

  defp origin(base_url) do
    uri = URI.parse(base_url)
    port = if uri.port in [80, 443, nil], do: "", else: ":#{uri.port}"
    "#{uri.scheme}://#{uri.host}#{port}"
  end

  defp ensure_leading_slash(value) do
    if String.starts_with?(value, "/"), do: value, else: "/" <> value
  end
end
