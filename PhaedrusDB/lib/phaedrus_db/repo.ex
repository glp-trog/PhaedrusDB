defmodule PhaedrusDB.Repo do
  use Ecto.Repo,
    otp_app: :phaedrus_db,
    adapter: Ecto.Adapters.Postgres
end
