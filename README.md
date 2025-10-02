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

## Setup Instructions
1. Install Elixir and PostgreSQL.
2. Clone the repository: `https://github.com/glp-trog/PhaedrusDB`.
3. Navigate to the project directory: `cd PhaedrusDB`.
4. Install dependencies: 'mix deps.get`.
5. Setup database: `mix ecto.create && mix ecto.migrate`.

## Dependencies
- Elixir `~> 1.14`
- Ecto `~> 3.12`
- PostgreSQL `>= 12.0`

## Testing
Run tests with: `mix test`.

## License
This project is licensed under the MIT License.
