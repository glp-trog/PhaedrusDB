defmodule PhaedrusDB.Observations do
  @moduledoc """
  Timeline / sightings layer for PhaedrusDB entries.

  An observation points at an immutable entry via its `content_hash`.
  """

  import Ecto.Query, warn: false

  alias PhaedrusDB.{CryptoId, Observation, Repo}

  @doc "Create an observation for a content_id."
  def observe(content_id, attrs) when is_map(attrs) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id) do
      attrs2 =
        attrs
        |> Map.put_new("observed_at", DateTime.utc_now() |> DateTime.truncate(:second))
        |> Map.put("content_hash", hash)

      %Observation{}
      |> Observation.changeset(attrs2)
      |> Repo.insert()
    end
  end

  @doc "List observations for a content_id (newest first)." 
  def list_for(content_id, limit \\ 50) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id) do
      q =
        from o in Observation,
          where: o.content_hash == ^hash,
          order_by: [desc: o.observed_at, desc: o.inserted_at],
          limit: ^limit

      {:ok, Repo.all(q)}
    end
  end
end
