defmodule PhaedrusDB.Keyring do
  @moduledoc """
  Local key storage for signing.

  Mode B: generate a local key file and load it on boot.

  This currently stores ONLY a 32-byte private key (hex). Public key derivation and
  Schnorr signing are implemented in `PhaedrusDB.Schnorr` (currently a stub).

  Key file format (JSON):
  {
    "scheme": "secp256k1",
    "privkey_hex": "...64 hex chars...",
    "created_at": "2026-...Z"
  }

  Path:
  - env `PHAEDRUS_KEY_PATH` or default `./phaedrus_key.json`
  """

  require Logger

  @default_path "phaedrus_key.json"

  def path do
    System.get_env("PHAEDRUS_KEY_PATH", @default_path)
  end

  @spec ensure!() :: :ok
  def ensure! do
    p = path()

    if File.exists?(p) do
      :ok
    else
      priv = :crypto.strong_rand_bytes(32)
      doc = %{
        "scheme" => "secp256k1",
        "privkey_hex" => Base.encode16(priv, case: :lower),
        "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      File.write!(p, Jason.encode!(doc, pretty: true) <> "\n")
      Logger.warning("Created new key file at #{p}. BACK IT UP; changing it changes signing identity.")
      :ok
    end
  end

  @spec privkey!() :: binary()
  def privkey! do
    ensure!()
    p = path()
    {:ok, json} = File.read(p)
    doc = Jason.decode!(json)

    hex = doc["privkey_hex"] || raise "Missing privkey_hex in #{p}"

    case Base.decode16(hex, case: :mixed) do
      {:ok, <<_::binary-size(32)>> = priv} -> priv
      {:ok, other} -> raise "Bad privkey length in #{p}: #{byte_size(other)}"
      :error -> raise "Bad privkey hex in #{p}"
    end
  end
end
