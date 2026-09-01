defmodule Mix.Tasks.Grimoire.Build do
  @shortdoc "Builds the site"

  @moduledoc """
  Runs a full site build: `Config.load → Scanner.scan → Builder.build`.

      $ mix grimoire.build
      $ mix grimoire.build --source path/to/site --dest _site --verbose
      $ mix grimoire.build --clean
  """

  use Mix.Task

  alias Grimoire.CLI.Commands

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    case Commands.build(argv) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("Build failed: #{inspect(reason)}")
    end
  end
end
