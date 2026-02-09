import Config

config :phaedrus_db, PhaedrusDB.Repo,
  database: "phaedrus_db_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

if url = System.get_env("PHAEDRUS_TEST_DB_URL") do
  config :phaedrus_db, PhaedrusDB.Repo, url: url
end
