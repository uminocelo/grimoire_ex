defmodule Mix.Tasks.Grimoire.Build do
  @shortdoc "Builds the site"

  @moduledoc """
  Runs a full site build: `Config.load → Scanner.scan → Builder.build`.

      $ mix grimoire.build
      $ mix grimoire.build --source path/to/site --dest _site --verbose

  `Grimoire.Scanner` and `Grimoire.Builder` land in later milestones — until
  then this task loads and validates config, and reports what it would do
  next, without failing.
  """

  use Mix.Task

  alias Grimoire.CLI.Logger, as: Log
  alias Grimoire.Config

  @switches [source: :string, dest: :string, verbose: :boolean]

  @impl Mix.Task
  def run(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: @switches)

    source = Keyword.get(opts, :source, ".")
    verbose = Keyword.get(opts, :verbose, false)
    start = System.monotonic_time(:millisecond)

    Log.step("Loading config from #{Path.join(source, "config.exs")}")
    config = Config.load(source)
    destination = Keyword.get(opts, :dest, config.destination)
    output_dir = Path.join(source, destination)

    if verbose do
      Log.step("Site: #{inspect(config.title)}, output: #{output_dir}")
    end

    Log.warn("Scanner/Builder are not wired yet (later milestones) — nothing was written")

    Log.summary(%{
      title: config.title,
      output_dir: output_dir,
      duration_ms: System.monotonic_time(:millisecond) - start
    })
  end
end
