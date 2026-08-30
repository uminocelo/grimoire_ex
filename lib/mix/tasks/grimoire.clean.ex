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

  alias Grimoire.CLI.Logger, as: Log

  @switches [source: :string, dest: :string]

  @impl Mix.Task
  def run(argv) do
    {opts, _rest} = OptionParser.parse!(argv, strict: @switches)

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
  end
end
