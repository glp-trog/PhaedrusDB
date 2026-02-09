defmodule PhaedrusDB.Repo.Migrations.CreateEntries do
  use Ecto.Migration

  def change do
    create table(:entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :payload, :map, null: false
      add :content_hash, :bytea, null: false

      add :pubkey, :bytea
      add :sig, :bytea

      timestamps()
    end

    create unique_index(:entries, [:content_hash])
  end
end
