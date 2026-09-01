defmodule Grimoire.Builder do
  @moduledoc """
  Orchestrates the full build: a `%Site{}` becomes a populated `_site/`
  directory. Steps run in sequence — `Router.check_collisions/1` (fail
  fast, before any file is written) → prepare the destination → render
  posts and pages in parallel via `Task.async_stream/3` → tag/category
  archive pages → paginated index pages (page 1 is the homepage) →
  RSS/Atom feeds → sitemap → static assets.

  A single post/page's render failure is recorded in the result's
  `:errors` and does not stop the rest of the build; a URL collision
  between two posts/pages aborts the whole build before any file under
  `_site/` is written. A generated archive page (tag/category/pagination,
  including the page-1 homepage) that would land on a URL already claimed
  by an actual post or page is skipped instead — author content wins.
  """

  alias Grimoire.{
    Assets,
    Categorizer,
    Collection,
    Feed,
    Paginator,
    Renderer,
    Router,
    Site,
    Sitemap,
    Tagger
  }

  @type summary :: %{
          posts_written: non_neg_integer(),
          pages_written: non_neg_integer(),
          archive_pages_written: non_neg_integer(),
          assets_copied: non_neg_integer(),
          feed_generated: boolean(),
          sitemap_generated: boolean(),
          errors: [{String.t(), term()}],
          duration_ms: non_neg_integer()
        }

  @doc """
  Builds `site`. `opts[:clean]` (default `false`) deletes
  `config.destination` before building; without it, an existing
  destination is built into in place (allows incremental builds under
  `grimoire.serve`). `opts[:verbose]` (default `false`) prints every
  written file's path.
  """
  @spec build(Site.t(), keyword()) :: {:ok, summary()} | {:error, term()}
  def build(site, opts \\ []) do
    start = System.monotonic_time(:millisecond)
    config = site.config
    published_posts = Collection.from_posts(site.posts)

    with {:ok} <- check_collisions(published_posts, site.pages) do
      prepare_destination(config, opts)

      {post_results, post_errors} =
        render_and_write(published_posts, site, config, &Renderer.render_post/3, opts)

      {page_results, page_errors} =
        render_and_write(site.pages, site, config, &Renderer.render_page/3, opts)

      taken_urls = MapSet.new(published_posts ++ site.pages, & &1.url)
      {archive_pages, archive_errors} = archive_pages(site.posts, site, config, taken_urls)
      Enum.each(archive_pages, &write_file(&1.output_path, &1.html, opts))

      write_file(feed_path(config), Feed.rss(published_posts, config), opts)
      write_file(atom_path(config), Feed.atom(published_posts, config), opts)
      write_file(sitemap_path(config), Sitemap.generate(site, config), opts)

      %{copied: assets_copied} = Assets.copy(site, config)

      {:ok,
       %{
         posts_written: length(post_results),
         pages_written: length(page_results),
         archive_pages_written: length(archive_pages),
         assets_copied: assets_copied,
         feed_generated: true,
         sitemap_generated: true,
         errors: post_errors ++ page_errors ++ archive_errors,
         duration_ms: System.monotonic_time(:millisecond) - start
       }}
    end
  end

  @doc """
  Opt-in incremental variant of `build/2`: skips re-rendering a post or
  page whose output is newer than both its source and every layout file.
  """
  @spec incremental_build(Site.t(), keyword()) :: {:ok, summary()} | {:error, term()}
  def incremental_build(site, opts \\ []) do
    build(site, Keyword.put(opts, :incremental, true))
  end

  defp check_collisions(published_posts, pages) do
    entries =
      Enum.map(published_posts, &{&1.url, &1.source_path}) ++
        Enum.map(pages, &{&1.url, &1.source_path})

    Router.check_collisions(entries)
  end

  defp prepare_destination(config, opts) do
    if Keyword.get(opts, :clean, false), do: File.rm_rf!(config.destination)
    File.mkdir_p!(config.destination)
  end

  defp archive_pages(posts, site, config, taken_urls) do
    {pages, errors} =
      (Tagger.generate_pages(posts, site, config) ++
         Categorizer.generate_pages(posts, site, config) ++
         Paginator.generate_pages(posts, site, config))
      |> Enum.reduce({[], []}, fn
        {:error, %{reason: reason, source: source}}, {pages, errors} ->
          {pages, [{source, reason} | errors]}

        page, {pages, errors} ->
          {[page | pages], errors}
      end)

    {Enum.reject(pages, &MapSet.member?(taken_urls, &1.url)), errors}
  end

  defp render_and_write(items, site, config, render_fun, opts) do
    layout_deadline =
      if Keyword.get(opts, :incremental, false), do: max_layout_mtime(site.root)

    items
    |> Task.async_stream(&render_item(&1, site, config, render_fun, layout_deadline, opts),
      max_concurrency: System.schedulers_online(),
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Enum.reduce({[], []}, &collect_result/2)
  end

  defp collect_result({:ok, {:ok, item}}, {oks, errors}), do: {[item | oks], errors}

  defp collect_result({:ok, {:error, %{reason: reason, source: source}}}, {oks, errors}),
    do: {oks, [{source, reason} | errors]}

  defp collect_result({:exit, reason}, {oks, errors}), do: {oks, [{:unknown, reason} | errors]}

  defp render_item(item, site, config, render_fun, layout_deadline, opts) do
    if layout_deadline && up_to_date?(item, layout_deadline) do
      {:ok, item}
    else
      case render_fun.(item, site, config) do
        {:ok, html} ->
          write_file(item.output_path, html, opts)
          {:ok, item}

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp up_to_date?(item, layout_deadline) do
    File.exists?(item.output_path) and
      mtime(item.output_path) >= mtime(item.source_path) and
      mtime(item.output_path) >= layout_deadline
  end

  defp max_layout_mtime(site_root) do
    layouts_dir = Path.join(site_root, "_layouts")

    if File.dir?(layouts_dir) do
      layouts_dir
      |> File.ls!()
      |> Enum.map(&mtime(Path.join(layouts_dir, &1)))
      |> Enum.max(fn -> 0 end)
    else
      0
    end
  end

  defp mtime(path), do: File.stat!(path, time: :posix).mtime

  defp write_file(path, content, opts) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    if Keyword.get(opts, :verbose, false), do: IO.puts(path)
    :ok
  end

  defp feed_path(config), do: Path.join(config.destination, "feed.xml")
  defp atom_path(config), do: Path.join(config.destination, "atom.xml")
  defp sitemap_path(config), do: Path.join(config.destination, "sitemap.xml")
end
