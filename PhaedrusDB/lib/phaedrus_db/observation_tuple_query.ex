defmodule PhaedrusDB.ObservationTupleQuery do
  @moduledoc false

  import Ecto.Query

  alias PhaedrusDB.{Observation, Repo}

  def get_by_tuple(%{content_hash: hash, source: source, observed_at: observed_at, url: url}) do
    base =
      from o in Observation,
        where: o.content_hash == ^hash and o.source == ^source and o.observed_at == ^observed_at

    q =
      if is_nil(url) do
        from o in base, where: is_nil(o.url)
      else
        from o in base, where: o.url == ^url
      end

    Repo.one(q)
  end
end
