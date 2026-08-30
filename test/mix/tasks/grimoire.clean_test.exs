defmodule Mix.Tasks.Grimoire.CleanTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  setup do
    dir = Path.join(System.tmp_dir!(), "grimoire_clean_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "deletes an existing _site directory", %{dir: dir} do
    site_dir = Path.join(dir, "_site")
    File.mkdir_p!(site_dir)
    File.write!(Path.join(site_dir, "index.html"), "hi")

    output =
      capture_io(fn -> Mix.Tasks.Grimoire.Clean.run(["--source", dir]) end)

    refute File.exists?(site_dir)
    assert output =~ "Deleting"
  end

  test "handles a missing _site directory without raising", %{dir: dir} do
    site_dir = Path.join(dir, "_site")
    refute File.exists?(site_dir)

    output =
      capture_io(fn -> Mix.Tasks.Grimoire.Clean.run(["--source", dir]) end)

    assert output =~ "does not exist"
  end
end
