import Config

config :phaedrus_db, ecto_repos: [PhaedrusDB.Repo]

config :phaedrus_db, PhaedrusDB.Repo,
  database: "phaedrus_db",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :logger, level: :info

import_config "#{config_env()}.exs"
