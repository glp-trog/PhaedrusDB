# PhaedrusDB

PhaedrusDB is a robust database solution for high-performance data handling.

## Features
- **Designed for Data Integrity and Security**.
- **High Performance:** Optimized for 100K-300K transactions per second (TPS).
- **Unique Indexing:** Data indexed using cryptographic signatures for rapid retrieval.
- **Elixir-Based:** Built using Elixir and Ecto for scalability and concurrency.
- **Cryptographic Indexing**: Assigns unique public keys to data entries for ultra-fast lookups.
- **Easily Extendable**: Support for videos, images, and structured data.
- **Optimized for Scalability**: Hybrid compression and retrieval schemes.

## Commands
- `mix ecto.create`: Create the database.
- `mix ecto.migrate`: Run database migrations.
- `mix run`: Execute scripts.
- `iex -S mix`: Start the interactive Elixir shell.
- `PhaedrusDB.CSVParser.parse_file("path/to/file.csv")`: Import CSV data.
- `PhaedrusDB.Repo.aggregate(PhaedrusDB.Model, :count, :id)`: Count rows.
- `PhaedrusDB.Repo.get(PhaedrusDB.Model, id)`: Retrieve a record by ID.

## Quickstart (Windows)

### 0) Toolchain note (important)
You need **matching Erlang/OTP + Elixir** builds.

If you have Erlang/OTP 28 installed, install an Elixir build compiled for OTP 28.
A mismatched combo (e.g. Elixir compiled for OTP 25 running on OTP 28) can break `mix deps.get`.

### 1) Start Postgres (recommended)

From repo root:
```bash
docker compose up -d
```

### 2) Install deps + create DB + migrate

```bash
cd PhaedrusDB
mix deps.get
mix ecto.create
mix ecto.migrate
```

### 3) Run tests

```bash
mix test
```

Env overrides:
- `PHAEDRUS_DB_URL` (dev)
- `PHAEDRUS_TEST_DB_URL` (test)

## Dependencies
- Elixir `~> 1.14`
- Ecto `~> 3.12`
- PostgreSQL `>= 12.0`

## Testing
Run tests with: `mix test`.

## License
This project is licensed under the MIT License.
