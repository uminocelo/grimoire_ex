defmodule Grimoire.CLI do
  @moduledoc """
  Escript entry point for Grimoire (`./grimoire ...`) — a self-contained
  binary bundling compiled BEAM bytecode, runnable on any machine with
  Erlang on `PATH`, without Elixir or Mix installed.

      $ grimoire build [--source PATH] [--dest PATH] [--verbose] [--clean]
      $ grimoire serve [--source PATH] [--port N] [--no-watch]
      $ grimoire new SITE_DIRECTORY
      $ grimoire clean [--source PATH] [--dest PATH]
      $ grimoire --version
      $ grimoire --help

  Delegates to `Grimoire.CLI.Commands`, the same pipeline `mix
  grimoire.*` uses — the only difference here is starting the `:grimoire`
  OTP application (a `mix` invocation does this via `app.start`; a bare
  escript does not) and using `System.halt/1` on failure instead of
  `Mix.raise/1`.
  """

  @version Mix.Project.config()[:version]

  alias Grimoire.CLI.Commands
  alias Grimoire.CLI.Logger, as: Log

  @doc false
  @spec main([String.t()]) :: :ok
  def main(argv) do
    {:ok, _apps} = Application.ensure_all_started(:grimoire)
    dispatch(argv)
  end

  defp dispatch(["--version"]), do: IO.puts("Grimoire v#{@version}")
  defp dispatch(["--help"]), do: help()
  defp dispatch(["build" | args]), do: halt_on_error(Commands.build(args))
  defp dispatch(["serve" | args]), do: Commands.serve(args)
  defp dispatch(["new" | args]), do: halt_on_error(Commands.new(args))
  defp dispatch(["clean" | args]), do: Commands.clean(args)
  defp dispatch([]), do: help_and_halt()
  defp dispatch(_unmatched), do: help_and_halt()

  defp halt_on_error(:ok), do: :ok

  defp halt_on_error({:error, reason}) do
    Log.error(to_string(reason))
    System.halt(1)
  end

  defp help_and_halt do
    help()
    System.halt(1)
  end

  defp help do
    IO.puts("""
    Grimoire v#{@version} — a zero-runtime-dependency static site generator.

    Usage:
      grimoire build [--source PATH] [--dest PATH] [--verbose] [--clean]
      grimoire serve [--source PATH] [--port N] [--no-watch]
      grimoire new SITE_DIRECTORY
      grimoire clean [--source PATH] [--dest PATH]
      grimoire --version
      grimoire --help
    """)
  end
end
