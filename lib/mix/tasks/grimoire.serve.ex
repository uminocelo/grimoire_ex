defmodule Mix.Tasks.Grimoire.Serve do
  @shortdoc "Builds the site, then serves it locally with live rebuilds"

  @moduledoc """
  Runs a full build, then starts the dev server and file watcher.

      $ mix grimoire.serve
      $ mix grimoire.serve --port 4001 --source path/to/site --no-watch

  `Grimoire.DevServer` and `Grimoire.Watcher` land in a later milestone —
  until then this task runs the build and reports what it would start next,
  without failing.
  """

  use Mix.Task

  alias Grimoire.CLI.Logger, as: Log

  @switches [port: :integer, source: :string, watch: :boolean]

  @impl Mix.Task
  def run(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: @switches)
    watch? = Keyword.get(opts, :watch, true)
    port = Keyword.get(opts, :port, 4000)
    source = Keyword.get(opts, :source, ".")

    Mix.Task.run("grimoire.build", ["--source", source])

    Log.warn(
      "DevServer/Watcher are not wired yet (later milestone) — " <>
        "would now serve #{source} on port #{port}" <>
        if(watch?, do: " with the watcher enabled", else: " with the watcher disabled")
    )
  end
end
