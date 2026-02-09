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
- `iex -S mix`: Start the interactive Elixir shell.

## Content-addressed JSONB (current)
PhaedrusDB currently supports storing JSONB payloads addressed by a cryptographic content hash.

Example (in `iex -S mix`):
```elixir
{:ok, res} = PhaedrusDB.put(%{"hello" => "world", "n" => 1})
res.content_id
{:ok, entry} = PhaedrusDB.get(res.content_id)
entry.payload
```

Under the hood:
- payload is canonicalized deterministically
- `content_hash = sha256(canonical_bytes(payload))`
- `content_id` is base64url(hash)

## Schnorr signatures (BIP340, secp256k1)
PhaedrusDB can optionally sign entries (tamper-evidence/authorship) using **BIP340 Schnorr** over secp256k1.

Key storage (local file):
- default: `./phaedrus_key.json`
- override with `PHAEDRUS_KEY_PATH`

**Back up this key file.** Changing it changes signing identity.

## HTTP API

Start the server:
```bash
set PHAEDRUS_DB_URL=postgres://postgres:YOURPASS@localhost:5432/phaedrus_db
mix deps.get
mix ecto.create
mix ecto.migrate
mix run --no-halt
```

Endpoints:
- `GET /health`
- `POST /entries` with JSON `{ "payload": { ... }, "sign": true|false }` → `{ "content_id": "...", "proof"?: {...} }`
- `GET /entries/:content_id` → `{ content_id, payload, inserted_at, pubkey_b64?, sig_b64?, proof }`
- `GET /proof/:content_id` → `{ content_id, proof }` (no payload)
- `POST /entries/:content_id/sign` → `{ content_id, pubkey_b64, sig_b64 }`
- `POST /entries/:content_id/verify` → `{ content_id, ok }` (requires stored signature)
- `POST /verify` with JSON `{ content_id, pubkey_b64, sig_b64 }` → `{ content_id, ok }` (stateless)

Observations (timeline/sightings):
- `POST /observe` with JSON `{ content_id, source, observed_at?, url?, notes?, tags?, meta? }`
- `GET /observations/:content_id?limit=50` → `{ content_id, observations:[...] }`

Default port: `4007` (override with `PHAEDRUS_HTTP_PORT`).

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
