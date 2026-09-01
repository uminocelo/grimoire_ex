defmodule Grimoire.FrontMatter do
  @moduledoc """
  Extracts and parses the `---`-delimited front matter block at the top of
  a content file into an Elixir map, with a hand-written line-by-line
  parser — no YAML dependency.

  ## Key representation

  A fixed whitelist of known front matter keys (`title`, `date`, `layout`,
  `tags`, `categories`, `category`, `excerpt`, `published`, `permalink`) is
  converted to atoms via `String.to_atom/1` — safe because the whitelist is
  small and fixed at compile time, so the atom table cannot grow unbounded
  regardless of how many content files a site has. Any other key is kept
  as a **string** key instead: turning arbitrary front matter keys into
  atoms would let a malicious or typo'd site file exhaust the atom table
  (`String.to_atom/1` never garbage collects), and
  `String.to_existing_atom/1` would just raise on the first typo. An
  unrecognized key is logged as a warning and kept, not dropped — front
  matter forward compatibility.
  """

  require Logger

  @known_keys ~w(title date layout tags categories category excerpt published permalink)

  @type meta :: %{optional(atom() | String.t()) => term()}

  defmodule MissingFieldError do
    @moduledoc "Raised by `validate_post!/1` / `validate_page!/1` when a required field is absent."

    defexception [:field]

    @impl true
    def message(%{field: field}) do
      "front matter is missing required field: #{inspect(field)}"
    end
  end

  @doc """
  Splits `content` into its front matter map and body.

  Returns `{%{}, content}` unchanged when `content` has no leading `---`
  block.
  """
  @spec parse(String.t()) :: {meta(), String.t()}
  def parse(content) do
    case String.split(content, "---\n", parts: 3) do
      ["", meta_block, body] -> {parse_meta(meta_block), body}
      _ -> {%{}, content}
    end
  end

  @doc "Requires `:title` (string) and `:date` (`Date.t()`) in `meta`, raising `MissingFieldError` otherwise."
  @spec validate_post!(meta()) :: :ok
  def validate_post!(meta) do
    unless is_binary(Map.get(meta, :title)), do: raise(MissingFieldError, field: :title)
    unless match?(%Date{}, Map.get(meta, :date)), do: raise(MissingFieldError, field: :date)
    :ok
  end

  @doc "Requires `:title` (string) in `meta`, raising `MissingFieldError` otherwise."
  @spec validate_page!(meta()) :: :ok
  def validate_page!(meta) do
    unless is_binary(Map.get(meta, :title)), do: raise(MissingFieldError, field: :title)
    :ok
  end

  defp parse_meta(meta_block) do
    meta_block
    |> String.split("\n")
    |> Enum.reject(&(String.trim(&1) == ""))
    |> parse_lines(%{})
  end

  defp parse_lines([], acc), do: acc

  defp parse_lines([line | rest], acc) do
    case Regex.run(~r/^([A-Za-z0-9_-]+):\s*$/, line) do
      [_, key] ->
        {items, remaining} = take_list_items(rest)
        parse_lines(remaining, put_value(acc, key, items))

      nil ->
        case Regex.run(~r/^([A-Za-z0-9_-]+):\s*(.+)$/, line) do
          [_, key, value] -> parse_lines(rest, put_value(acc, key, coerce_value(value)))
          nil -> parse_lines(rest, acc)
        end
    end
  end

  defp take_list_items(lines), do: take_list_items(lines, [])

  defp take_list_items([line | rest], acc) do
    case Regex.run(~r/^\s+-\s+(.+)$/, line) do
      [_, item] -> take_list_items(rest, [String.trim(item) | acc])
      nil -> {Enum.reverse(acc), [line | rest]}
    end
  end

  defp take_list_items([], acc), do: {Enum.reverse(acc), []}

  defp put_value(acc, key_string, value) do
    if key_string in @known_keys do
      Map.put(acc, String.to_atom(key_string), value)
    else
      Logger.warning("Grimoire.FrontMatter: unrecognized front matter key #{inspect(key_string)}")
      Map.put(acc, key_string, value)
    end
  end

  defp coerce_value(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "true" -> true
      trimmed == "false" -> false
      Regex.match?(~r/^-?\d+$/, trimmed) -> String.to_integer(trimmed)
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, trimmed) -> Date.from_iso8601!(trimmed)
      true -> trimmed
    end
  end
end
