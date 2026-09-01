defmodule Mix.Tasks.Grimoire.NewTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  setup do
    dir = Path.join(System.tmp_dir!(), "grimoire_new_test_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "creates every expected starter file with content interpolated", %{dir: dir} do
    site_dir = Path.join(dir, "my_site")

    capture_io(fn -> Mix.Tasks.Grimoire.New.run([site_dir]) end)

    assert File.regular?(Path.join(site_dir, "config.exs"))
    assert File.regular?(Path.join(site_dir, "_layouts/base.html"))
    assert File.regular?(Path.join(site_dir, "_layouts/post.html"))
    assert File.regular?(Path.join(site_dir, "_layouts/index.html"))
    assert File.regular?(Path.join(site_dir, "_pages/about.md"))
    assert File.regular?(Path.join(site_dir, "assets/css/style.css"))

    today = Date.to_iso8601(Date.utc_today())
    post_path = Path.join(site_dir, "_posts/#{today}-hello-grimoire.md")
    assert File.regular?(post_path)

    config = File.read!(Path.join(site_dir, "config.exs"))
    assert config =~ "title: \"My Site\""
    refute config =~ "<%="

    layout = File.read!(Path.join(site_dir, "_layouts/base.html"))
    refute layout =~ "<%="
  end

  test "errors without touching the directory when it already exists", %{dir: dir} do
    site_dir = Path.join(dir, "existing_site")
    File.mkdir_p!(site_dir)
    File.write!(Path.join(site_dir, "sentinel.txt"), "keep me")

    assert_raise Mix.Error, ~r/already exists/, fn ->
      capture_io(fn -> Mix.Tasks.Grimoire.New.run([site_dir]) end)
    end

    assert File.ls!(site_dir) == ["sentinel.txt"]
  end
end
