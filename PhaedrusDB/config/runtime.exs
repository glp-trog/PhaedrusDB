import Config

# Production-style runtime config via env vars.
# Example:
#   PHAEDRUS_DB_URL=postgres://user:pass@host:5432/phaedrus_db

if config_env() == :prod do
  if url = System.get_env("PHAEDRUS_DB_URL") do
    config :phaedrus_db, PhaedrusDB.Repo, url: url
  end
end
