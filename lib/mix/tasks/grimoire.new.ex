defmodule Mix.Tasks.Grimoire.New do
  @shortdoc "Scaffolds a new Grimoire site"

  @moduledoc """
  Scaffolds a new Grimoire site directory.

      $ mix grimoire.new my_site

  Never overwrites an existing directory.
  """

  use Mix.Task

  alias Grimoire.CLI.Commands

  @impl Mix.Task
  def run(argv) do
    case Commands.new(argv) do
      :ok -> :ok
      {:error, reason} -> Mix.raise(to_string(reason))
    end
  end
end
