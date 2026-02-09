import Config

# Override via env vars if you want:
#   set PHAEDRUS_DB_URL=postgres://postgres:postgres@localhost:5432/phaedrus_db
#   mix ecto.create && mix ecto.migrate

if url = System.get_env("PHAEDRUS_DB_URL") do
  config :phaedrus_db, PhaedrusDB.Repo, url: url
end
