defmodule Mix.Tasks.Grimoire.Serve do
  @shortdoc "Builds the site, then serves it locally with live rebuilds"

  @moduledoc """
  Runs a full build, then starts the dev server and file watcher.

      $ mix grimoire.serve
      $ mix grimoire.serve --port 4001 --source path/to/site --no-watch

  Runs in the foreground; `Ctrl+C` (twice, standard `mix` behaviour) stops
  it.
  """

  use Mix.Task

  alias Grimoire.CLI.Commands

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    Commands.serve(argv)
  end
end
