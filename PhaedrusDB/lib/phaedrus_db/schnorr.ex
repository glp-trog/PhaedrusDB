defmodule PhaedrusDB.Schnorr do
  @moduledoc """
  Schnorr signatures (planned).

  This is intentionally a stub for now.

  Next step is to plug in a real BIP340 secp256k1 Schnorr implementation
  (likely via a NIF/port library). Once added, implement:
  - `pubkey_from_privkey/1`
  - `sign_hash/2`
  - `verify_hash/3`
  """

  @type privkey :: <<_::256>>
  @type pubkey :: binary()
  @type sig :: binary()

  @spec pubkey_from_privkey(privkey()) :: {:ok, pubkey()} | {:error, term()}
  def pubkey_from_privkey(_priv), do: {:error, :not_implemented}

  @spec sign_hash(<<_::256>>, privkey()) :: {:ok, sig()} | {:error, term()}
  def sign_hash(_hash32, _priv), do: {:error, :not_implemented}

  @spec verify_hash(<<_::256>>, sig(), pubkey()) :: boolean()
  def verify_hash(_hash32, _sig, _pub), do: false
end
