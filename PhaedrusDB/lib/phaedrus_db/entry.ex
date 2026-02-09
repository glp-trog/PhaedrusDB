defmodule PhaedrusDB.Entry do
  @moduledoc """An immutable JSONB payload addressed by a cryptographic content hash."""

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "entries" do
    field :payload, :map
    field :content_hash, :binary

    # reserved for future Schnorr support
    field :pubkey, :binary
    field :sig, :binary

    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:payload, :content_hash, :pubkey, :sig])
    |> validate_required([:payload, :content_hash])
    |> unique_constraint(:content_hash)
  end
end
