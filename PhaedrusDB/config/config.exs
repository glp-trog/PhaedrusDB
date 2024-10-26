use Mix.Config

config :phaedrus_db, PhaedrusDB.Repo,
  database: "phaedrus_db",
  username: "your_user",
  password: "your_password",
  hostname: "localhost"

config :logger, level: :info
