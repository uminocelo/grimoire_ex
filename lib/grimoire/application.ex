defmodule Grimoire.Application do
  @moduledoc false

  use Application

  @filters [
    Grimoire.Filters.DateToString,
    Grimoire.Filters.DateToXmlschema,
    Grimoire.Filters.XmlEscape,
    Grimoire.Filters.Slugify,
    Grimoire.Filters.RelativeUrl,
    Grimoire.Filters.AbsoluteUrl
  ]

  @impl true
  def start(_type, _args) do
    Application.put_env(:alembic, :custom_filters, @filters)
    Supervisor.start_link([], strategy: :one_for_one, name: Grimoire.Supervisor)
  end
end
