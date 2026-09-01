defmodule Grimoire.WatcherTest do
  use ExUnit.Case, async: false

  alias Grimoire.{Config, Watcher}

  defp fixture_site! do
    dir = Path.join(System.tmp_dir!(), "grimoire_watcher_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(dir, "_posts"))
    File.mkdir_p!(Path.join(dir, "_layouts"))

    File.write!(Path.join(dir, "_layouts/base.html"), "<html>{{ content }}</html>")

    File.write!(Path.join(dir, "config.exs"), """
    %{title: "Fixture", base_url: "https://example.com"}
    """)

    File.write!(Path.join(dir, "_posts/2024-01-01-first.md"), """
    ---
    title: First
    ---

    Body.
    """)

    dir
  end

  defp unique_name, do: :"watcher_test_#{System.unique_integer([:positive])}"

  defp start_watcher!(dir, extra_opts \\ []) do
    config = Config.load(dir)
    name = unique_name()
    test_pid = self()

    opts =
      [
        site_root: dir,
        config: config,
        name: name,
        poll_interval: 20,
        debounce: 80,
        on_rebuild: fn site -> send(test_pid, {:rebuilt, site}) end
      ]
      |> Keyword.merge(extra_opts)

    {:ok, pid} = GenServer.start_link(Watcher, opts, name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    {pid, name}
  end

  describe "diff/2" do
    test "classifies added, modified, and deleted files" do
      old = %{"a" => 100, "b" => 100, "c" => 100}
      new = %{"a" => 100, "b" => 200, "d" => 300}

      assert Watcher.diff(old, new) == %{added: ["d"], modified: ["b"], deleted: ["c"]}
    end

    test "returns nil when nothing changed" do
      snapshot = %{"a" => 100, "b" => 200}
      assert Watcher.diff(snapshot, snapshot) == nil
    end
  end

  describe "polling and debounced rebuild" do
    test "a single file save produces one rebuild, with the changed path visible" do
      dir = fixture_site!()
      on_exit(fn -> File.rm_rf!(dir) end)
      {_pid, _name} = start_watcher!(dir)

      Process.sleep(30)
      post = Path.join(dir, "_posts/2024-01-01-first.md")
      File.write!(post, "---\ntitle: First (edited)\n---\n\nBody.\n")

      assert_receive {:rebuilt, site}, 1_000
      assert Enum.any?(site.posts, &(&1.title == "First (edited)"))
    end

    test "5 rapid saves within the debounce window trigger exactly one rebuild" do
      dir = fixture_site!()
      on_exit(fn -> File.rm_rf!(dir) end)
      {_pid, _name} = start_watcher!(dir, debounce: 150)

      Process.sleep(30)
      post = Path.join(dir, "_posts/2024-01-01-first.md")

      for i <- 1..5 do
        File.write!(post, "---\ntitle: Edit #{i}\n---\n\nBody.\n")
        Process.sleep(20)
      end

      assert_receive {:rebuilt, _site}, 1_000
      refute_receive {:rebuilt, _site}, 300
    end

    test "a deleted source file is detected and the subsequent build succeeds without it" do
      dir = fixture_site!()
      on_exit(fn -> File.rm_rf!(dir) end)
      {_pid, _name} = start_watcher!(dir)

      Process.sleep(30)
      File.rm!(Path.join(dir, "_posts/2024-01-01-first.md"))

      assert_receive {:rebuilt, site}, 1_000
      assert site.posts == []
    end

    test "a new _posts/ file is detected and included" do
      dir = fixture_site!()
      on_exit(fn -> File.rm_rf!(dir) end)
      {_pid, _name} = start_watcher!(dir)

      Process.sleep(30)

      File.write!(Path.join(dir, "_posts/2024-01-02-second.md"), """
      ---
      title: Second
      ---

      New body.
      """)

      assert_receive {:rebuilt, site}, 1_000
      assert Enum.any?(site.posts, &(&1.title == "Second"))
    end
  end
end
