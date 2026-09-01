defmodule Grimoire.Assets do
  @moduledoc """
  Copies static files into `_site/`: verbatim `assets/` directory copy,
  root-level pass-through files (e.g. `robots.txt`, `favicon.ico`,
  `CNAME`, `.nojekyll` — any regular file that isn't `_*`-prefixed or
  `config.exs`), and optional MD5 cache-busting fingerprinting.

  Fingerprinting (`config.fingerprint_assets: true`) renames each asset
  under `assets/` to embed 8 hex characters of its content's MD5 hash
  (`style.css` → `style.ab12cd34.css`), and writes the resulting
  original-path → fingerprinted-path manifest to
  `_site/assets/manifest.json`. Pass-through files are never
  fingerprinted.

  An asset whose destination is already at least as new as its source is
  skipped on a repeat build — unless fingerprinting is enabled, in which
  case every asset is always re-hashed (its content, not just its mtime,
  may have changed).
  """

  alias Grimoire.{Config, Site}

  @type manifest :: %{String.t() => String.t()}

  @doc """
  Copies `site.root/assets/` and every eligible root-level pass-through
  file into `config.destination`. Returns the number of files actually
  written and the asset manifest — an identity map
  (`"assets/x.css" => "assets/x.css"`) when `config.fingerprint_assets`
  is `false`, otherwise mapping each original path to its fingerprinted
  one.
  """
  @spec copy(Site.t(), Config.t()) :: %{copied: non_neg_integer(), manifest: manifest()}
  def copy(site, config) do
    {asset_copied, manifest} = copy_assets(site.root, config)
    passthrough_copied = copy_passthrough(site.root, config)

    if config.fingerprint_assets, do: write_manifest(manifest, config)

    %{copied: asset_copied + passthrough_copied, manifest: manifest}
  end

  defp copy_assets(site_root, config) do
    assets_dir = Path.join(site_root, "assets")

    if File.dir?(assets_dir) do
      assets_dir
      |> walk_files()
      |> Enum.map(&copy_asset(&1, assets_dir, config))
      |> Enum.reduce({0, %{}}, fn {copied?, {key, value}}, {count, manifest} ->
        {count + bool_to_int(copied?), Map.put(manifest, key, value)}
      end)
    else
      {0, %{}}
    end
  end

  defp bool_to_int(true), do: 1
  defp bool_to_int(false), do: 0

  defp copy_asset(source_path, assets_dir, config) do
    relative = Path.relative_to(source_path, assets_dir)
    original_key = Path.join("assets", relative)

    if config.fingerprint_assets do
      fingerprint_asset(source_path, relative, original_key, config)
    else
      plain_asset(source_path, relative, original_key, config)
    end
  end

  defp plain_asset(source_path, relative, original_key, config) do
    dest_path = Path.join([config.destination, "assets", relative])

    copied? =
      if up_to_date?(source_path, dest_path) do
        false
      else
        File.mkdir_p!(Path.dirname(dest_path))
        File.cp!(source_path, dest_path)
        true
      end

    {copied?, {original_key, original_key}}
  end

  defp fingerprint_asset(source_path, relative, original_key, config) do
    content = File.read!(source_path)
    hash = content |> md5_hash8()

    fingerprinted_relative = fingerprinted_path(relative, hash)
    dest_path = Path.join([config.destination, "assets", fingerprinted_relative])

    File.mkdir_p!(Path.dirname(dest_path))
    File.write!(dest_path, content)

    {true, {original_key, Path.join("assets", fingerprinted_relative)}}
  end

  defp fingerprinted_path(relative, hash) do
    dirname = Path.dirname(relative)
    basename = Path.basename(relative)
    ext = Path.extname(basename)
    rootname = Path.basename(basename, ext)
    fingerprinted_basename = "#{rootname}.#{hash}#{ext}"

    if dirname == ".", do: fingerprinted_basename, else: Path.join(dirname, fingerprinted_basename)
  end

  defp md5_hash8(content) do
    :md5 |> :crypto.hash(content) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  defp copy_passthrough(site_root, config) do
    site_root
    |> File.ls!()
    |> Enum.filter(&passthrough?(site_root, &1))
    |> Enum.count(fn entry ->
      source_path = Path.join(site_root, entry)
      dest_path = Path.join(config.destination, entry)

      if up_to_date?(source_path, dest_path) do
        false
      else
        File.mkdir_p!(config.destination)
        File.cp!(source_path, dest_path)
        true
      end
    end)
  end

  defp passthrough?(site_root, entry) do
    full = Path.join(site_root, entry)
    File.regular?(full) and entry != "config.exs" and not String.starts_with?(entry, "_")
  end

  defp up_to_date?(source_path, dest_path) do
    File.exists?(dest_path) and mtime(dest_path) >= mtime(source_path)
  end

  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  defp walk_files(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      full = Path.join(dir, entry)

      cond do
        File.dir?(full) -> walk_files(full)
        File.regular?(full) -> [full]
        true -> []
      end
    end)
  end

  defp write_manifest(manifest, config) do
    path = Path.join([config.destination, "assets", "manifest.json"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, encode_manifest(manifest))
  end

  defp encode_manifest(manifest) do
    entries = Enum.map_join(manifest, ",", fn {k, v} -> "#{json_string(k)}:#{json_string(v)}" end)
    "{" <> entries <> "}"
  end

  defp json_string(value) do
    escaped = value |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"")
    "\"" <> escaped <> "\""
  end
end
