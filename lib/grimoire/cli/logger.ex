defmodule Grimoire.CLI.Logger do
  @moduledoc """
  Coloured terminal output for Grimoire's Mix tasks and escript. Colour is
  skipped automatically when the output isn't a TTY (`IO.ANSI.enabled?/0`).
  """

  @step_timer_key {__MODULE__, :last_step_at}

  @doc """
  Prints a labelled build step, prefixed with `→`. Each call after the
  first in the current process prints the elapsed time since the previous
  `step/1` call.
  """
  @spec step(String.t()) :: :ok
  def step(label) do
    now = System.monotonic_time(:millisecond)

    suffix =
      case Process.get(@step_timer_key) do
        nil -> ""
        last -> " (+#{now - last}ms)"
      end

    Process.put(@step_timer_key, now)
    puts(:cyan, "→ #{label}#{suffix}")
  end

  @doc "Prints a green success line, prefixed with a checkmark."
  @spec success(String.t()) :: :ok
  def success(label), do: puts(:green, "✓ #{label}")

  @doc "Prints a yellow warning line, prefixed with a warning glyph."
  @spec warn(String.t()) :: :ok
  def warn(label), do: puts(:yellow, "⚠ #{label}")

  @doc "Prints a red error line, prefixed with a cross."
  @spec error(String.t()) :: :ok
  def error(label), do: puts(:red, "✗ #{label}")

  @doc """
  Prints a final build summary table from a `label => value` enumerable,
  e.g. `%{posts_written: 11, duration_ms: 42}`.
  """
  @spec summary(Enumerable.t()) :: :ok
  def summary(fields) do
    rows = Enum.map(fields, fn {label, value} -> {to_label(label), to_string(value)} end)
    width = rows |> Enum.map(fn {label, _} -> String.length(label) end) |> Enum.max(fn -> 0 end)

    puts(:bright, "Build summary")

    Enum.each(rows, fn {label, value} ->
      IO.puts("  #{String.pad_trailing(label, width)}  #{value}")
    end)

    :ok
  end

  defp to_label(label) when is_atom(label) do
    label |> Atom.to_string() |> String.replace("_", " ")
  end

  defp to_label(label), do: to_string(label)

  defp puts(color, text) do
    if IO.ANSI.enabled?() do
      IO.puts(IO.ANSI.format([color, text]))
    else
      IO.puts(text)
    end
  end
end
