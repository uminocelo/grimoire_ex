defmodule Grimoire.Test.Fixtures do
  @moduledoc """
  Helpers for locating fixture site directories under `test/fixtures/`.
  """

  @fixtures_root Path.join([__DIR__, "..", "fixtures"])

  @doc """
  Absolute path to a fixture site directory by name, e.g.
  `site_path("minimal_site")`.
  """
  @spec site_path(String.t()) :: String.t()
  def site_path(name) do
    @fixtures_root
    |> Path.join(name)
    |> Path.expand()
  end
end
