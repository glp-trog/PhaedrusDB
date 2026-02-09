defmodule PhaedrusDB.Repo.Migrations.CreateObservations do
  use Ecto.Migration

  def change do
    create table(:observations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :content_hash, :bytea, null: false
      add :source, :text, null: false
      add :observed_at, :utc_datetime, null: false

      add :url, :text
      add :notes, :text
      add :tags, {:array, :text}
      add :meta, :map

      timestamps()
    end

    create index(:observations, [:content_hash])
    create index(:observations, [:observed_at])
    create index(:observations, [:source])
  end
end
