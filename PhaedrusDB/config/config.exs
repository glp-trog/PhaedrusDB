import Config

config :phaedrus_db, ecto_repos: [PhaedrusDB.Repo]

config :phaedrus_db, PhaedrusDB.Repo,
  database: "phaedrus_db",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :logger, level: :info

import_config "#{config_env()}.exs"
