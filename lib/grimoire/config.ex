defmodule Grimoire.Config do
  @moduledoc """
  Site configuration, loaded from a site's `config.exs`.

  `config.exs` is a plain Elixir file evaluated with `Code.eval_file/1` — it
  must return a map of config keys. See `docs/config.md` for the full field
  reference.
  """

  @enforce_keys [:title, :base_url]
  defstruct [
    :title,
    :base_url,
    :author,
    :description,
    source: ".",
    destination: "_site",
    paginate: 10,
    permalink: :pretty,
    feed_posts: 20,
    timezone: "UTC",
    generate_tags: true,
    generate_categories: true,
    fingerprint_assets: false
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          base_url: String.t(),
          author: String.t() | nil,
          description: String.t() | nil,
          source: String.t(),
          destination: String.t(),
          paginate: pos_integer() | false,
          permalink: :pretty | :date | :ordinal | String.t(),
          feed_posts: pos_integer(),
          timezone: String.t(),
          generate_tags: boolean(),
          generate_categories: boolean(),
          fingerprint_assets: boolean()
        }

  @required_fields [:title, :base_url]

  @doc """
  Loads and evaluates a site's `config.exs`, merging the result with
  defaults.

  `path` is the site root directory (containing `config.exs`), not the
  path to `config.exs` itself.

  Raises `ArgumentError` if `:title` or `:base_url` is missing from the
  evaluated config.
  """
  @spec load(String.t()) :: t()
  def load(path) do
    config_path = Path.join(path, "config.exs")
    {raw, _bindings} = Code.eval_file(config_path)

    raw
    |> validate!()
    |> then(&struct!(__MODULE__, &1))
  end

  defp validate!(raw) do
    missing = Enum.filter(@required_fields, &(not Map.has_key?(raw, &1)))

    if missing != [] do
      raise ArgumentError,
            "config.exs is missing required field(s): #{Enum.map_join(missing, ", ", &inspect/1)}"
    end

    raw
  end
end
