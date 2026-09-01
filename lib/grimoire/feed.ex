defmodule Grimoire.Feed do
  @moduledoc """
  Generates RSS 2.0 (`rss/2`) and Atom 1.0 (`atom/2`) feeds for published
  posts via pure iolist string building — no XML library needed. Intended
  output paths are `_site/feed.xml` and `_site/atom.xml`, respectively
  (written by `Grimoire.Builder`, milestone 4.1).

  Every user-provided string (title, excerpt) is passed through
  `Grimoire.Filters.XmlEscape`; dates through
  `Grimoire.Filters.DateToXmlschema`. Limited to `config.feed_posts` most
  recent published posts (default 20).
  """

  alias Grimoire.Collection
  alias Grimoire.Filters.{DateToXmlschema, UrlHelpers, XmlEscape}

  @doc "Generates the RSS 2.0 feed document."
  @spec rss([Grimoire.Post.t()], Grimoire.Config.t()) :: String.t()
  def rss(posts, config) do
    Application.put_env(:grimoire, :base_url, config.base_url)
    items = posts |> recent(config) |> Enum.map_join("\n", &rss_item/1)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>#{escape(config.title)}</title>
        <link>#{escape(config.base_url)}</link>
        <description>#{escape(config.description || "")}</description>
        <lastBuildDate>#{rfc822(DateTime.utc_now())}</lastBuildDate>
        <generator>Grimoire</generator>
    #{items}
      </channel>
    </rss>
    """
  end

  @doc "Generates the Atom 1.0 feed document."
  @spec atom([Grimoire.Post.t()], Grimoire.Config.t()) :: String.t()
  def atom(posts, config) do
    Application.put_env(:grimoire, :base_url, config.base_url)
    recent_posts = recent(posts, config)
    entries = Enum.map_join(recent_posts, "\n", &atom_entry/1)
    updated = recent_posts |> List.first() |> feed_updated()

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <id>#{escape(config.base_url)}</id>
      <title>#{escape(config.title)}</title>
      <updated>#{updated}</updated>
      <author><name>#{escape(config.author || config.title)}</name></author>
      <link href="#{escape(config.base_url)}"/>
    #{entries}
    </feed>
    """
  end

  defp recent(posts, config) do
    posts |> Collection.from_posts() |> Enum.take(config.feed_posts)
  end

  defp rss_item(post) do
    url = absolute(post.url)

    """
      <item>
        <title>#{escape(post.title)}</title>
        <link>#{url}</link>
        <description>#{escape(post.excerpt)}</description>
        <pubDate>#{rfc822(post.date)}</pubDate>
        <guid isPermaLink="true">#{url}</guid>
      </item>
    """
  end

  defp atom_entry(post) do
    url = absolute(post.url)

    """
      <entry>
        <id>#{url}</id>
        <title>#{escape(post.title)}</title>
        <updated>#{xmlschema(post.date)}</updated>
        <summary>#{escape(post.excerpt)}</summary>
        <content type="html">#{escape(post.content_html)}</content>
        <link href="#{url}"/>
      </entry>
    """
  end

  defp feed_updated(nil), do: xmlschema(Date.utc_today())
  defp feed_updated(%Grimoire.Post{date: date}), do: xmlschema(date)

  defp escape(value) do
    {:ok, escaped} = XmlEscape.apply(value, [])
    escaped
  end

  defp xmlschema(date) do
    {:ok, formatted} = DateToXmlschema.apply(date, [])
    formatted
  end

  defp absolute(url), do: UrlHelpers.absolute(url)

  defp rfc822(%Date{} = date), do: date |> DateTime.new!(~T[00:00:00], "Etc/UTC") |> rfc822()

  defp rfc822(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S %z")
end
