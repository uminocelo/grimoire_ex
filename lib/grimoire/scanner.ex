defmodule Grimoire.Scanner do
  @moduledoc """
  Walks a site source directory, classifies every file, and builds the
  populated `%Grimoire.Site{}` by parsing all content files in parallel via
  `Task.async_stream/3`.

  ## File classification

  | Path pattern | Classification |
  |---|---|
  | `_posts/*.md` | `:post` |
  | `_pages/*.md` | `:page` |
  | `_layouts/*.html` | `:layout` (not parsed as content) |
  | `_includes/*.html` | `:include` (not parsed as content) |
  | `assets/**/*` | `:asset` |
  | `*.{txt,ico,xml,json}` at root | `:passthrough` |
  | `_site/**`, `config.exs`, dotfiles | ignored |
  """

  require Logger

  alias Grimoire.{Collection, Config, Page, Post, Site}

  @passthrough_extensions ~w(.txt .ico .xml .json)

  @doc """
  Scans `site_root` and returns a fully populated `%Site{}`. Accepts an
  optional pre-loaded `config` (e.g. with an overridden `:destination`)
  instead of loading `site_root`'s `config.exs` again — every post/page's
  `url`/`output_path` is computed against it.
  """
  @spec scan(String.t(), Config.t() | nil) :: Site.t()
  def scan(site_root, config \\ nil) do
    config = config || Config.load(site_root)
    buckets = site_root |> walk() |> Enum.group_by(&classify_full_path(&1, site_root))

    posts =
      buckets
      |> Map.get(:post, [])
      |> parse_parallel(config, &Post.from_file/2)
      |> Enum.sort_by(& &1.date, {:desc, Date})

    pages =
      buckets
      |> Map.get(:page, [])
      |> parse_parallel(config, &Page.from_file/2)
      |> Enum.sort_by(& &1.slug)

    assets =
      Enum.map(Map.get(buckets, :asset, []), &asset_entry(&1, site_root, config, :asset)) ++
        Enum.map(
          Map.get(buckets, :passthrough, []),
          &asset_entry(&1, site_root, config, :passthrough)
        )

    %Site{
      config: config,
      root: site_root,
      posts: posts,
      pages: pages,
      assets: assets,
      tags: Collection.by_tag(posts),
      categories: Collection.by_category(posts)
    }
  end

  @doc "Classifies a path relative to the site root."
  @spec classify(String.t()) ::
          :post | :page | :layout | :include | :asset | :passthrough | :ignore
  def classify(relative_path) do
    cond do
      dotfile?(relative_path) -> :ignore
      relative_path == "config.exs" -> :ignore
      String.starts_with?(relative_path, "_posts/") and md?(relative_path) -> :post
      String.starts_with?(relative_path, "_pages/") and md?(relative_path) -> :page
      String.starts_with?(relative_path, "_layouts/") and html?(relative_path) -> :layout
      String.starts_with?(relative_path, "_includes/") and html?(relative_path) -> :include
      String.starts_with?(relative_path, "assets/") -> :asset
      root_level?(relative_path) and passthrough_ext?(relative_path) -> :passthrough
      true -> :ignore
    end
  end

  defp classify_full_path(full_path, site_root) do
    full_path |> Path.relative_to(site_root) |> classify()
  end

  defp md?(path), do: String.ends_with?(path, ".md")
  defp html?(path), do: String.ends_with?(path, ".html")
  defp root_level?(path), do: not String.contains?(path, "/")
  defp passthrough_ext?(path), do: Path.extname(path) in @passthrough_extensions

  defp dotfile?(relative_path) do
    relative_path
    |> Path.split()
    |> Enum.any?(&String.starts_with?(&1, "."))
  end

  defp walk(dir) do
    dir
    |> File.ls!()
    |> Enum.reject(&skip_entry?/1)
    |> Enum.flat_map(fn entry ->
      full = Path.join(dir, entry)

      cond do
        File.dir?(full) -> walk(full)
        File.regular?(full) -> [full]
        true -> []
      end
    end)
  end

  defp skip_entry?(entry), do: entry == "_site" or String.starts_with?(entry, ".")

  defp parse_parallel(paths, config, from_file_fun) do
    paths
    |> Task.async_stream(&safe_parse(&1, config, from_file_fun), timeout: 5_000)
    |> Enum.reduce([], fn
      {:ok, {:ok, item}}, acc ->
        [item | acc]

      {:ok, {:error, {path, reason}}}, acc ->
        Logger.warning("Grimoire.Scanner: failed to parse #{path}: #{reason}")
        acc

      {:exit, reason}, acc ->
        Logger.warning("Grimoire.Scanner: parse task exited: #{inspect(reason)}")
        acc
    end)
  end

  defp safe_parse(path, config, from_file_fun) do
    {:ok, from_file_fun.(path, config)}
  rescue
    e -> {:error, {path, Exception.message(e)}}
  end

  defp asset_entry(full_path, site_root, config, type) do
    relative = Path.relative_to(full_path, site_root)
    %{source: full_path, destination: Path.join(config.destination, relative), type: type}
  end
end
