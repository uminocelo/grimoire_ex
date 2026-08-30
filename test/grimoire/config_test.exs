defmodule Grimoire.ConfigTest do
  use ExUnit.Case, async: true

  alias Grimoire.Config
  import Grimoire.Test.Fixtures

  describe "load/1" do
    test "returns a %Config{} populated from a fixture config.exs" do
      config = Config.load(site_path("minimal_site"))

      assert %Config{
               title: "Fixture Site",
               base_url: "https://example.com",
               author: "Test Author",
               description: "A minimal fixture site for Grimoire.Config tests."
             } = config
    end

    test "unset optional fields fall back to documented defaults" do
      config = Config.load(site_path("minimal_site"))

      assert config.source == "."
      assert config.destination == "_site"
      assert config.paginate == 10
      assert config.permalink == :pretty
      assert config.feed_posts == 20
      assert config.timezone == "UTC"
    end

    test "raises with the missing field name when required fields are absent" do
      error =
        assert_raise ArgumentError, fn ->
          Config.load(site_path("missing_required_site"))
        end

      assert error.message =~ ":title"
      assert error.message =~ ":base_url"
    end
  end
end
