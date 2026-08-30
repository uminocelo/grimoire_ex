defmodule Grimoire.SiteGenerator do
  @moduledoc """
  Generates the starter files for a new Grimoire site (`mix grimoire.new`).

  Starter file contents are read at **compile time** via `@external_resource`
  + `File.read!/1`, so they are embedded directly in the compiled module —
  available even from the escript binary, which does not bundle `priv/`.
  """

  starter_dir = Path.expand("../../priv/starter", __DIR__)

  templates = %{
    config: Path.join(starter_dir, "config.exs.eex"),
    base_layout: Path.join(starter_dir, "layouts/base.html.eex"),
    post_layout: Path.join(starter_dir, "layouts/post.html.eex"),
    about_page: Path.join(starter_dir, "pages/about.md.eex"),
    hello_post: Path.join(starter_dir, "posts/hello-grimoire.md.eex")
  }

  for {_name, path} <- templates do
    @external_resource path
  end

  @config_template File.read!(templates.config)
  @base_layout_template File.read!(templates.base_layout)
  @post_layout_template File.read!(templates.post_layout)
  @about_page_template File.read!(templates.about_page)
  @hello_post_template File.read!(templates.hello_post)

  style_css_path = Path.join(starter_dir, "assets/css/style.css")
  @external_resource style_css_path
  @style_css File.read!(style_css_path)

  @doc """
  Generates a new site at `dir`, with `site_title` interpolated into the
  starter templates. Returns `{:error, :already_exists}` without touching
  the directory if it already exists — never overwrites.
  """
  @spec generate(String.t(), String.t()) :: :ok | {:error, :already_exists}
  def generate(dir, site_title) do
    if File.exists?(dir) do
      {:error, :already_exists}
    else
      today = Date.to_iso8601(Date.utc_today())
      assigns = [site_title: site_title, today: today]

      write!(Path.join(dir, "config.exs"), render(@config_template, assigns))
      write!(Path.join(dir, "_layouts/base.html"), render(@base_layout_template, assigns))
      write!(Path.join(dir, "_layouts/post.html"), render(@post_layout_template, assigns))
      write!(Path.join(dir, "_pages/about.md"), render(@about_page_template, assigns))

      write!(
        Path.join(dir, "_posts/#{today}-hello-grimoire.md"),
        render(@hello_post_template, assigns)
      )

      write!(Path.join(dir, "assets/css/style.css"), @style_css)

      :ok
    end
  end

  defp render(template, assigns), do: EEx.eval_string(template, assigns: assigns)

  defp write!(path, content) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
  end
end
