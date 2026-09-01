defmodule Mix.Tasks.Grimoire.Clean do
  @shortdoc "Deletes the site's output directory"

  @moduledoc """
  Deletes the generated `_site/` directory.

      $ mix grimoire.clean
      $ mix grimoire.clean --source path/to/site --dest _site

  Handles a missing output directory gracefully — this is a no-op, not an
  error.
  """

  use Mix.Task

  alias Grimoire.CLI.Commands

  @impl Mix.Task
  def run(argv) do
    Commands.clean(argv)
  end
end
