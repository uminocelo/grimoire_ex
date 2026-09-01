defmodule Grimoire.AssetsTest do
  use ExUnit.Case, async: true

  alias Grimoire.{Assets, Config, Site}

  defp tmp_dir! do
    dir = Path.join(System.tmp_dir!(), "grimoire_assets_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp write!(root, relative, content) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    path
  end

  defp config(root, overrides \\ %{}) do
    struct(
      %Config{title: "T", base_url: "https://example.com", destination: Path.join(root, "_site")},
      overrides
    )
  end

  defp site(root, config) do
    %Site{root: root, config: config}
  end

  describe "copy/2" do
    test "every file under source/assets/ ends up at the matching path under _site/assets/" do
      root = tmp_dir!()
      write!(root, "assets/css/style.css", "body { color: red; }")
      write!(root, "assets/js/app.js", "console.log(1)")

      config = config(root)
      result = Assets.copy(site(root, config), config)

      assert File.read!(Path.join(config.destination, "assets/css/style.css")) ==
               "body { color: red; }"

      assert File.read!(Path.join(config.destination, "assets/js/app.js")) == "console.log(1)"
      assert result.copied == 2
    end

    test "pass-through files land at _site/ root, _* dirs and config.exs are never pass-through" do
      root = tmp_dir!()
      write!(root, "robots.txt", "User-agent: *")
      write!(root, "favicon.ico", "icon-bytes")
      write!(root, ".nojekyll", "")
      write!(root, "config.exs", "%{}")
      write!(root, "_posts/2024-01-01-a.md", "---\ntitle: A\n---\n")

      config = config(root)
      Assets.copy(site(root, config), config)

      assert File.read!(Path.join(config.destination, "robots.txt")) == "User-agent: *"
      assert File.read!(Path.join(config.destination, "favicon.ico")) == "icon-bytes"
      assert File.exists?(Path.join(config.destination, ".nojekyll"))
      refute File.exists?(Path.join(config.destination, "config.exs"))
      refute File.exists?(Path.join(config.destination, "_posts"))
    end

    test "with fingerprinting enabled, every asset's output filename embeds its content's MD5 hash" do
      root = tmp_dir!()
      write!(root, "assets/style.css", "body {}")

      config = config(root, %{fingerprint_assets: true})
      result = Assets.copy(site(root, config), config)

      assert %{"assets/style.css" => fingerprinted} = result.manifest
      assert fingerprinted =~ ~r|^assets/style\.[0-9a-f]{8}\.css$|
      assert File.exists?(Path.join(config.destination, fingerprinted))
    end

    test "manifest.json correctly maps every original asset path to its fingerprinted path" do
      root = tmp_dir!()
      write!(root, "assets/style.css", "body {}")
      write!(root, "assets/app.js", "1")

      config = config(root, %{fingerprint_assets: true})
      result = Assets.copy(site(root, config), config)

      manifest_json = File.read!(Path.join(config.destination, "assets/manifest.json"))

      Enum.each(result.manifest, fn {original, fingerprinted} ->
        assert manifest_json =~ ~s("#{original}":"#{fingerprinted}")
        assert File.exists?(Path.join(config.destination, fingerprinted))
      end)
    end

    test "with fingerprinting disabled, site.assets (the manifest) maps every original path to itself" do
      root = tmp_dir!()
      write!(root, "assets/style.css", "body {}")

      config = config(root)
      result = Assets.copy(site(root, config), config)

      assert result.manifest == %{"assets/style.css" => "assets/style.css"}
    end

    test "an unchanged asset with a destination at least as new as the source is not re-copied" do
      root = tmp_dir!()
      source = write!(root, "assets/style.css", "original")
      config = config(root)

      Assets.copy(site(root, config), config)
      dest = Path.join(config.destination, "assets/style.css")

      # Simulate a stale source (older than its already-built destination).
      File.touch!(dest, System.os_time(:second))
      File.touch!(source, System.os_time(:second) - 60)
      File.write!(source, "changed-but-should-be-skipped")

      result = Assets.copy(site(root, config), config)

      assert result.copied == 0
      assert File.read!(dest) == "original"
    end

    test "with fingerprinting enabled, assets are always re-copied/re-hashed regardless of mtime" do
      root = tmp_dir!()
      source = write!(root, "assets/style.css", "original")
      config = config(root, %{fingerprint_assets: true})

      Assets.copy(site(root, config), config)

      dest_marker = Path.join(config.destination, "assets/style.css") |> Path.dirname()
      File.touch!(dest_marker, System.os_time(:second))
      File.touch!(source, System.os_time(:second) - 60)

      result = Assets.copy(site(root, config), config)

      assert result.copied == 1
    end
  end
end
