defmodule PhaedrusDB.Repo.Migrations.AddObservationIdempotencyIndex do
  use Ecto.Migration

  def change do
    # Idempotency for retries: if you re-send the exact same observation tuple,
    # we won't create duplicates.
    # NOTE: Postgres treats NULLs as distinct in unique indexes; if url is NULL,
    # duplicates may still occur. Prefer providing a URL for true idempotency.
    create unique_index(:observations, [:content_hash, :source, :url, :observed_at],
             name: :observations_idempotency_uq
           )
  end
end
