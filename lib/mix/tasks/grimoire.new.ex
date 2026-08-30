defmodule Mix.Tasks.Grimoire.New do
  @shortdoc "Scaffolds a new Grimoire site"

  @moduledoc """
  Scaffolds a new Grimoire site directory.

      $ mix grimoire.new my_site

  Never overwrites an existing directory.
  """

  use Mix.Task

  alias Grimoire.CLI.Logger, as: Log
  alias Grimoire.SiteGenerator

  @impl Mix.Task
  def run(argv) do
    case argv do
      [dir | _rest] -> new_site(dir)
      [] -> Mix.raise("usage: mix grimoire.new SITE_DIRECTORY")
    end
  end

  defp new_site(dir) do
    site_title = dir |> Path.basename() |> humanize()

    case SiteGenerator.generate(dir, site_title) do
      :ok ->
        Log.success("Created #{dir}/")
        IO.puts("  → cd #{dir}")
        IO.puts("  → mix grimoire.serve")

      {:error, :already_exists} ->
        Mix.raise("directory #{inspect(dir)} already exists — grimoire.new never overwrites")
    end
  end

  defp humanize(name) do
    name
    |> String.split(~r/[-_]+/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
