defmodule Mix.Tasks.Grimoire.Build do
  @shortdoc "Builds the site"

  @moduledoc """
  Runs a full site build: `Config.load → Scanner.scan → Builder.build`.

      $ mix grimoire.build
      $ mix grimoire.build --source path/to/site --dest _site --verbose
      $ mix grimoire.build --clean
  """

  use Mix.Task

  alias Grimoire.CLI.Logger, as: Log
  alias Grimoire.{Builder, Config, Scanner}

  @switches [source: :string, dest: :string, verbose: :boolean, clean: :boolean]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {opts, _rest} = OptionParser.parse!(argv, strict: @switches)

    source = Keyword.get(opts, :source, ".")
    verbose = Keyword.get(opts, :verbose, false)
    clean = Keyword.get(opts, :clean, false)

    Log.step("Loading config from #{Path.join(source, "config.exs")}")
    config = Config.load(source)
    destination = Keyword.get(opts, :dest, config.destination)
    output_dir = output_dir(source, destination)
    config = %{config | destination: output_dir}

    if verbose, do: Log.step("Site: #{inspect(config.title)}, output: #{output_dir}")

    Log.step("Scanning #{source}")
    site = Scanner.scan(source, config)

    Log.step("Building")

    case Builder.build(site, verbose: verbose, clean: clean) do
      {:ok, summary} ->
        Enum.each(summary.errors, fn {source_path, reason} ->
          Log.error("#{source_path}: #{inspect(reason)}")
        end)

        Log.success("Build complete")
        Log.summary(Map.put(summary, :errors, length(summary.errors)))

      {:error, reason} ->
        Log.error("Build failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp output_dir(source, destination) do
    if Path.type(destination) == :absolute, do: destination, else: Path.join(source, destination)
  end
end
