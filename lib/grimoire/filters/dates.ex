defmodule Grimoire.Filters.Dates do
  @moduledoc false

  @spec parse(Date.t() | DateTime.t() | String.t()) :: {:ok, Date.t()} | {:error, term()}
  def parse(%Date{} = date), do: {:ok, date}
  def parse(%DateTime{} = datetime), do: {:ok, DateTime.to_date(datetime)}

  def parse(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        {:ok, date}

      {:error, _reason} ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} -> {:ok, DateTime.to_date(datetime)}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def parse(other), do: {:error, {:invalid_date, other}}
end
