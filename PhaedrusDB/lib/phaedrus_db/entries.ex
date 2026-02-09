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

  @doc "List most recent entries."
  def list_recent(limit \\ 20) do
    Repo.all(from e in Entry, order_by: [desc: e.inserted_at], limit: ^limit)
  end

  @doc "Sign an existing entry (stores pubkey+sig)."
  def sign(content_id) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id),
         %Entry{} = entry <- Repo.get_by(Entry, content_hash: hash),
         priv <- PhaedrusDB.Keyring.privkey!(),
         {:ok, pub} <- PhaedrusDB.Schnorr.pubkey_from_privkey(priv),
         {:ok, sig} <- PhaedrusDB.Schnorr.sign_hash(hash, priv) do
      entry
      |> Entry.changeset(%{pubkey: pub, sig: sig})
      |> Repo.update()
    else
      nil -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  @doc "Put then sign (convenience)."
  def put_and_sign(payload) do
    with {:ok, res} <- put(payload),
         {:ok, entry} <- sign(res.content_id) do
      {:ok, %{content_id: res.content_id, content_hash: res.content_hash, entry: entry}}
    end
  end

  @doc "Verify signature on an entry (if present)."
  def verify(content_id) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id),
         %Entry{} = entry <- Repo.get_by(Entry, content_hash: hash),
         true <- is_binary(entry.sig) and is_binary(entry.pubkey) do
      {:ok, PhaedrusDB.Schnorr.verify_hash(hash, entry.sig, entry.pubkey)}
    else
      nil -> {:error, :not_found}
      false -> {:error, :unsigned}
      {:error, _} = err -> err
    end
  end

  @doc "Stateless verify: verify a provided signature/pubkey against the content id."
  def verify_detached(content_id, pubkey, sig) when is_binary(pubkey) and is_binary(sig) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id) do
      {:ok, PhaedrusDB.Schnorr.verify_hash(hash, sig, pubkey)}
    end
  end

  def verify_detached(_content_id, _pubkey, _sig), do: {:error, :bad_params}
end
