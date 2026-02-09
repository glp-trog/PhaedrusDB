defmodule PhaedrusDB do
  @moduledoc """
  PhaedrusDB — Postgres/Ecto-backed content-addressed JSONB store (WIP).

  Current functionality:
  - Store JSONB payloads addressed by a cryptographic content hash (SHA-256)

  Planned:
  - Schnorr signatures over the content hash for tamper-evidence/authorship.
  """

  alias PhaedrusDB.Entries

  @doc "Ping function for sanity checks." 
  def ping, do: :pong

  @doc "Store a JSON payload and return its content id." 
  defdelegate put(payload), to: Entries

  @doc "Store + sign a JSON payload and return its content id + signature." 
  defdelegate put_and_sign(payload), to: Entries

  @doc "Fetch an entry by content id." 
  defdelegate get(content_id), to: Entries

  @doc "Sign an entry by content id (stores pubkey+sig)." 
  defdelegate sign(content_id), to: Entries

  @doc "Verify an entry signature (if present)." 
  defdelegate verify(content_id), to: Entries

  @doc "Stateless verify: verify provided pubkey+sig against the content id." 
  defdelegate verify_detached(content_id, pubkey, sig), to: Entries

  # Observations
  defdelegate observe(content_id, attrs), to: PhaedrusDB.Observations
  defdelegate observations(content_id, limit \\ 50), to: PhaedrusDB.Observations, as: :list_for
  defdelegate observations_recent(opts \\ %{}), to: PhaedrusDB.Observations, as: :list_recent
end
