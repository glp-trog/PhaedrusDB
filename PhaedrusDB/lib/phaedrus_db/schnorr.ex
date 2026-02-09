defmodule PhaedrusDB.Schnorr do
  @moduledoc """
  BIP340 Schnorr signatures over secp256k1.

  Implemented via a Rustler NIF in `native/phaedrus_schnorr`.

  Notes:
  - `pubkey` is x-only (32 bytes)
  - `sig` is 64 bytes
  - `hash32` must be exactly 32 bytes (we sign the SHA-256 content hash)
  """

  use Rustler,
    otp_app: :phaedrus_db,
    crate: "phaedrus_schnorr"

  @type privkey :: <<_::256>>
  @type pubkey :: <<_::256>>
  @type sig :: <<_::512>>

  @spec pubkey_from_privkey(privkey()) :: {:ok, pubkey()} | {:error, term()}
  def pubkey_from_privkey(priv) when is_binary(priv) and byte_size(priv) == 32 do
    {:ok, native_pubkey_from_privkey(priv)}
  rescue
    _ -> {:error, :bad_privkey}
  end

  @spec sign_hash(<<_::256>>, privkey()) :: {:ok, sig()} | {:error, term()}
  def sign_hash(hash32, priv) when is_binary(hash32) and byte_size(hash32) == 32 and is_binary(priv) and byte_size(priv) == 32 do
    {:ok, native_sign_hash(hash32, priv)}
  rescue
    _ -> {:error, :sign_failed}
  end

  @spec verify_hash(<<_::256>>, sig(), pubkey()) :: boolean()
  def verify_hash(hash32, sig64, pub32)
      when is_binary(hash32) and byte_size(hash32) == 32 and is_binary(sig64) and byte_size(sig64) == 64 and
             is_binary(pub32) and byte_size(pub32) == 32 do
    native_verify_hash(hash32, sig64, pub32)
  rescue
    _ -> false
  end

  # NIFs
  defp native_pubkey_from_privkey(_priv), do: :erlang.nif_error(:nif_not_loaded)
  defp native_sign_hash(_hash32, _priv), do: :erlang.nif_error(:nif_not_loaded)
  defp native_verify_hash(_hash32, _sig64, _pub32), do: :erlang.nif_error(:nif_not_loaded)
end
