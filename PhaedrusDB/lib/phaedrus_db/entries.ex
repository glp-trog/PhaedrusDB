defmodule PhaedrusDB.Entries do
  @moduledoc "Public API for content-addressed JSONB entries."

  import Ecto.Query, warn: false

  alias PhaedrusDB.{CryptoId, Entry, Repo}

  @type put_result ::
          {:ok, %{content_id: binary(), content_hash: binary(), entry: Entry.t()}}
          | {:error, term()}

  @doc """
  Store a JSONB payload and return its content id.

  - `payload` must be JSON-compatible (maps/lists/strings/numbers/bools/nil)
  - id is SHA-256 of canonicalized payload

  If the payload already exists, returns the existing entry.
  """
  @spec put(map() | list()) :: put_result()
  def put(payload) do
    hash = CryptoId.content_hash(payload)

    case Repo.get_by(Entry, content_hash: hash) do
      %Entry{} = entry ->
        {:ok, %{content_id: CryptoId.content_id(hash), content_hash: hash, entry: entry}}

      nil ->
        %Entry{}
        |> Entry.changeset(%{payload: payload, content_hash: hash})
        |> Repo.insert()
        |> case do
          {:ok, entry} -> {:ok, %{content_id: CryptoId.content_id(hash), content_hash: hash, entry: entry}}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc "Fetch by content id (base64url sha256)."
  @spec get(binary()) :: {:ok, Entry.t()} | {:error, term()}
  def get(content_id) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id),
         %Entry{} = entry <- Repo.get_by(Entry, content_hash: hash) do
      {:ok, entry}
    else
      nil -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  @doc """List most recent entries."""
  def list_recent(limit \\ 20) do
    Repo.all(from e in Entry, order_by: [desc: e.inserted_at], limit: ^limit)
  end
end
