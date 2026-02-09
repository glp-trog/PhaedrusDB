# PhaedrusDB

PhaedrusDB is a **content‑addressed JSONB store** (Postgres + Elixir/Ecto) with **BIP340 Schnorr signatures** and an **observations/timeline** layer.

It’s aimed at ETL/OSINT pipelines, audit trails, and “proof of publication” workflows where you want:
- deterministic IDs for payloads (dedupe + stable references)
- optional signatures (tamper‑evidence / authorship)
- a timeline of where/when something was observed

## Core concepts

### Content‑addressed entries
- You submit a JSON payload.
- We canonicalize it deterministically and compute:
  - `content_hash = sha256(canonical_bytes(payload))`
  - `content_id = base64url(content_hash)`
- That `content_id` is the stable identifier for the payload.

### Schnorr signatures (BIP340, secp256k1)
Entries can be signed (tamper‑evidence / authorship) using **BIP340 Schnorr**.

Key storage (local file):
- default: `./phaedrus_key.json`
- override with `PHAEDRUS_KEY_PATH`

Back up this key file. Changing it changes the signing identity.

### Observations (timeline / sightings)
Observations are separate rows that point at an immutable entry by `content_id` (via `content_hash`).

This is the “ETL/OSINT wedge”: you can keep appending sightings from different sources without mutating the payload.

---

## HTTP API

Default port: `4007` (override with `PHAEDRUS_HTTP_PORT`).

### Start the server (PowerShell)

```powershell
cd C:\Users\mr-ga\scripts\PhaedrusDB\PhaedrusDB
$env:PHAEDRUS_DB_URL = "postgres://postgres:YOURPASS@localhost:5432/phaedrus_db"

mix deps.get
mix ecto.create
mix ecto.migrate
mix run --no-halt
```

### Endpoints

**Health**
- `GET /health`

**Entries**
- `POST /entries` with JSON `{ "payload": { ... }, "sign": true|false }`
  - returns `{ "content_id": "...", "proof"?: {content_id,pubkey_b64,sig_b64} }`
- `GET /entries/:content_id`
  - returns `{ content_id, payload, inserted_at, pubkey_b64?, sig_b64?, proof }`
- `GET /proof/:content_id` (no payload)
  - returns `{ content_id, proof }`
- `POST /entries/:content_id/sign`
  - returns `{ content_id, pubkey_b64, sig_b64 }`
- `POST /entries/:content_id/verify` (requires stored signature)
  - returns `{ content_id, ok }`

**Stateless verify (portable proofs)**
- `POST /verify` with JSON `{ content_id, pubkey_b64, sig_b64 }`
  - returns `{ content_id, ok }`

**Observations (timeline/sightings)**
- `POST /observe`
  - either `{ content_id, source, observed_at?, url?, notes?, tags?, meta? }`
  - or `{ payload, sign?: true|false, source, observed_at?, url?, notes?, tags?, meta? }`
  - returns `{ content_id, proof?, observation: {...} }`
- `GET /observations/:content_id?limit=50`
  - returns `{ content_id, observations:[...] }`
- `GET /observations/recent?source=...&tag=...&since=...&before=...&limit=...`
  - returns `{ observations:[...], next_before }` (each item includes `content_id`)
  - pagination: pass `before=<next_before>` to fetch the next page
- `GET /sources?since=...&limit=...`
  - returns `{ sources:[{source,count,last_observed_at}] }`

---

## Quickstart (Windows)

### 0) Toolchain note (important)
You need **matching Erlang/OTP + Elixir** builds.

Example good state:
- Erlang/OTP 28
- Elixir compiled for OTP 28

### 1) Postgres
Install Postgres locally and ensure it’s running on `localhost:5432`.

### 2) Run tests
```powershell
cd C:\Users\mr-ga\scripts\PhaedrusDB\PhaedrusDB
$env:PHAEDRUS_TEST_DB_URL = "postgres://postgres:YOURPASS@localhost:5432/phaedrus_db_test"
$env:MIX_ENV = "test"

mix ecto.create
mix ecto.migrate
mix test

Remove-Item Env:\MIX_ENV
```

---

## License
MIT (add a `LICENSE` file if you want GitHub to show it explicitly).
