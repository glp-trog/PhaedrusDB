defmodule PhaedrusDB.Repo.Migrations.CreateExampleModels do
  use Ecto.Migration

  def change do
    create table(:example_models) do
      add :data, :text, null: false
      add :timestamp, :naive_datetime

      timestamps()
    end

    create index(:example_models, [:timestamp])
  end
end
