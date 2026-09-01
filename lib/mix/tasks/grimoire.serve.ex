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

  alias Grimoire.CLI.Logger, as: Log
  alias Grimoire.{Builder, Config, DevServer, Scanner, Watcher}

  @switches [port: :integer, source: :string, watch: :boolean]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")
    {opts, _rest} = OptionParser.parse!(argv, strict: @switches)

    watch? = Keyword.get(opts, :watch, true)
    port = Keyword.get(opts, :port, 4000)
    source = Keyword.get(opts, :source, ".")

    config =
      source |> Config.load() |> then(&%{&1 | destination: output_dir(source, &1.destination)})

    site = Scanner.scan(source, config)

    Log.step("Building")
    {:ok, _summary} = Builder.build(site)

    {:ok, _pid} = DevServer.start(document_root: config.destination, port: port)

    if watch? do
      {:ok, _pid} = Watcher.start(site_root: source, config: config, site: site)
    end

    Process.sleep(:infinity)
  end

  defp output_dir(source, destination) do
    if Path.type(destination) == :absolute, do: destination, else: Path.join(source, destination)
  end
end
