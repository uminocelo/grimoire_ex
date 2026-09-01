defmodule Grimoire.CLI.Commands do
  @moduledoc """
  Shared command implementations for `mix grimoire.*` and the `./grimoire`
  escript, so both entry points run the exact same build/serve/new/clean
  pipeline — only argument parsing and process startup differ between
  them.
  """

  alias Grimoire.{Builder, Config, DevServer, Scanner, SiteGenerator, Watcher}
  alias Grimoire.CLI.Logger, as: Log

  @build_switches [source: :string, dest: :string, verbose: :boolean, clean: :boolean]
  @serve_switches [port: :integer, source: :string, watch: :boolean]
  @clean_switches [source: :string, dest: :string]

  @doc """
  Runs a full build. Returns `:ok`, or `{:error, reason}` on failure
  (a URL collision — every other failure is per-item and accumulated
  into the build summary instead, see `Grimoire.Builder`). Callers
  decide how to surface `{:error, reason}` (`Mix.raise/1` vs.
  `System.halt/1`), since that differs between a Mix task and the
  escript.
  """
  @spec build([String.t()]) :: :ok | {:error, term()}
  def build(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: @build_switches)

    source = Keyword.get(opts, :source, ".")
    verbose = Keyword.get(opts, :verbose, false)
    clean? = Keyword.get(opts, :clean, false)

    Log.step("Loading config from #{Path.join(source, "config.exs")}")
    config = load_config(source, opts)
    if verbose, do: Log.step("Site: #{inspect(config.title)}, output: #{config.destination}")

    Log.step("Scanning #{source}")
    site = Scanner.scan(source, config)

    Log.step("Building")

    case Builder.build(site, verbose: verbose, clean: clean?) do
      {:ok, summary} ->
        Enum.each(summary.errors, fn {source_path, reason} ->
          Log.error("#{source_path}: #{inspect(reason)}")
        end)

        Log.success("Build complete")
        Log.summary(Map.put(summary, :errors, length(summary.errors)))
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Builds once, then starts the dev server (and, unless `--no-watch`, the
  file watcher). Runs in the foreground.
  """
  @spec serve([String.t()]) :: no_return()
  def serve(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: @serve_switches)

    watch? = Keyword.get(opts, :watch, true)
    port = Keyword.get(opts, :port, 4000)
    source = Keyword.get(opts, :source, ".")

    config = load_config(source, [])
    site = Scanner.scan(source, config)

    Log.step("Building")
    {:ok, _summary} = Builder.build(site)

    {:ok, _pid} = DevServer.start(document_root: config.destination, port: port)

    if watch? do
      {:ok, _pid} = Watcher.start(site_root: source, config: config, site: site)
    end

    Process.sleep(:infinity)
  end

  @doc """
  Scaffolds a new site directory. Returns `:ok`, or `{:error, reason}`
  if no directory is given or it already exists — see `build/1`'s doc
  for why the caller decides how to surface that.
  """
  @spec new([String.t()]) :: :ok | {:error, term()}
  def new(argv) do
    case argv do
      [dir | _rest] -> new_site(dir)
      [] -> {:error, "usage: grimoire new SITE_DIRECTORY"}
    end
  end

  @doc "Deletes the site's output directory. A missing directory is a no-op, not an error."
  @spec clean([String.t()]) :: :ok
  def clean(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: @clean_switches)

    source = Keyword.get(opts, :source, ".")
    dest = Keyword.get(opts, :dest, "_site")
    output_dir = Path.join(source, dest)

    if File.exists?(output_dir) do
      IO.puts("Deleting #{output_dir}/...")
      File.rm_rf!(output_dir)
      Log.success("Deleted #{output_dir}/")
    else
      Log.warn("#{output_dir}/ does not exist — nothing to clean")
    end

    :ok
  end

  defp load_config(source, opts) do
    config = Config.load(source)
    destination = Keyword.get(opts, :dest, config.destination)
    %{config | destination: output_dir(source, destination)}
  end

  defp output_dir(source, destination) do
    if Path.type(destination) == :absolute, do: destination, else: Path.join(source, destination)
  end

  defp new_site(dir) do
    site_title = dir |> Path.basename() |> humanize()

    case SiteGenerator.generate(dir, site_title) do
      :ok ->
        Log.success("Created #{dir}/")
        IO.puts("  → cd #{dir}")
        IO.puts("  → grimoire serve  (or: mix grimoire.serve)")
        :ok

      {:error, :already_exists} ->
        {:error, "directory #{inspect(dir)} already exists — grimoire new never overwrites"}
    end
  end

  defp humanize(name) do
    name
    |> String.split(~r/[-_]+/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
