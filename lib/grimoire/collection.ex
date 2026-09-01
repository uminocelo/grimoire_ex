defmodule Grimoire.Collection do
  @moduledoc """
  Groups, sorts, and paginates posts for the template layer and build
  pipeline.

  Full pagination *pages* (per-page URLs beyond the raw post chunks here)
  are `Grimoire.Paginator`'s job — see
  `.plan/branches/1/milestones/4/4.2.md`.
  """

  alias Grimoire.{Post, Router}

  @doc """
  Filters to published posts, sorted by date descending, with `next`
  (chronologically newer) and `previous` (chronologically older) populated
  — `nil` at the newest/oldest ends respectively.
  """
  @spec from_posts([Post.t()]) :: [Post.t()]
  def from_posts(posts) do
    posts
    |> Enum.filter(& &1.published)
    |> sort_by_date_desc()
    |> populate_next_previous()
  end

  @doc "Groups `posts` by tag, each group sorted by date descending."
  @spec by_tag([Post.t()]) :: %{optional(String.t()) => [Post.t()]}
  def by_tag(posts), do: group_by_field(posts, & &1.tags)

  @doc "Groups `posts` by category, each group sorted by date descending."
  @spec by_category([Post.t()]) :: %{optional(String.t()) => [Post.t()]}
  def by_category(posts), do: group_by_field(posts, & &1.categories)

  @doc """
  Splits `posts` (assumed already sorted) into pages of `per_page`,
  returning one map per page:
  `%{posts:, page:, total_pages:, previous_url:, next_url:}`.
  """
  @spec paginate([Post.t()], pos_integer()) :: [map()]
  def paginate(posts, per_page) when is_integer(per_page) and per_page > 0 do
    chunks = Enum.chunk_every(posts, per_page)
    total_pages = max(length(chunks), 1)

    chunks
    |> Enum.with_index(1)
    |> Enum.map(fn {page_posts, page} ->
      %{
        posts: page_posts,
        page: page,
        total_pages: total_pages,
        previous_url: if(page > 1, do: Router.pagination_url(page - 1)),
        next_url: if(page < total_pages, do: Router.pagination_url(page + 1))
      }
    end)
  end

  @doc """
  Up to 3 posts (excluding `post` itself, sorted by date descending) that
  share at least one tag with `post`.
  """
  @spec related(Post.t(), [Post.t()]) :: [Post.t()]
  def related(%Post{} = post, posts) do
    tag_set = MapSet.new(post.tags)

    posts
    |> Enum.reject(&(&1.source_path == post.source_path))
    |> Enum.filter(&Enum.any?(&1.tags, fn tag -> MapSet.member?(tag_set, tag) end))
    |> sort_by_date_desc()
    |> Enum.take(3)
  end

  defp group_by_field(posts, field_fun) do
    Enum.reduce(posts, %{}, fn post, acc ->
      Enum.reduce(field_fun.(post), acc, fn key, acc ->
        Map.update(acc, key, [post], &[post | &1])
      end)
    end)
    |> Map.new(fn {key, group} -> {key, sort_by_date_desc(group)} end)
  end

  defp sort_by_date_desc(posts), do: Enum.sort_by(posts, & &1.date, {:desc, Date})

  defp populate_next_previous(posts) do
    count = length(posts)

    posts
    |> Enum.with_index()
    |> Enum.map(fn {post, i} ->
      %{
        post
        | next: if(i > 0, do: Enum.at(posts, i - 1)),
          previous: if(i < count - 1, do: Enum.at(posts, i + 1))
      }
    end)
  end
end
