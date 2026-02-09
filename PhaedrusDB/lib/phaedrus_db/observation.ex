defmodule PhaedrusDB.Observation do
  @moduledoc "A sighting of a content-addressed entry from some source." 

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "observations" do
    field :content_hash, :binary

    field :source, :string
    field :observed_at, :utc_datetime
    field :url, :string
    field :notes, :string
    field :tags, {:array, :string}
    field :meta, :map

    timestamps()
  end

  def changeset(obs, attrs) do
    obs
    |> cast(attrs, [:content_hash, :source, :observed_at, :url, :notes, :tags, :meta])
    |> validate_required([:content_hash, :source, :observed_at])
    |> validate_length(:source, min: 1, max: 200)
    |> validate_length(:url, max: 2000)
    |> validate_length(:notes, max: 4000)
    |> unique_constraint(:observed_at, name: :observations_idempotency_uq)
  end
end
