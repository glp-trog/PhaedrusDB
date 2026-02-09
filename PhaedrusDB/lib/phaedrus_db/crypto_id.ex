defmodule PhaedrusDB.CryptoId do
  @moduledoc """
  Deterministic cryptographic identifiers for JSONB payloads.

  This implements a *stable* (canonical) byte representation of an Elixir term
  that corresponds to JSON data, then hashes it.

  Why not hash raw JSON text?
  - JSON text is not canonical by default (whitespace and key order differ).

  Canonicalization here:
  - Map keys are sorted lexicographically by their string form
  - Values are recursively normalized
  - The canonical bytes are an Erlang external term format of the normalized term
    (`:erlang.term_to_binary/2` with compression disabled)

  This gives stable hashing/signing inputs while keeping `payload` stored as `jsonb`.

  NOTE: Schnorr signatures are not implemented yet; this module provides the
  hash + content_id foundation that signatures can build on.
  """

  @type json_scalar :: nil | boolean() | number() | binary()
  @type json_value :: json_scalar() | [json_value()] | %{optional(binary()) => json_value()}

  @doc """Normalize a JSON-like Elixir term into a deterministic structure."""
  @spec normalize(term()) :: term()
  def normalize(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {key_to_string(k), normalize(v)} end)
    |> Enum.sort_by(fn {k, _} -> k end)
  end

  def normalize(value) when is_list(value) do
    Enum.map(value, &normalize/1)
  end

  def normalize(value) when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value), do: value

  def normalize(other) do
    raise ArgumentError,
          "payload contains non-JSON value: #{inspect(other)} (allowed: maps/lists/strings/numbers/bools/nil)"
  end

  @doc """Return canonical bytes for hashing/signing."""
  @spec canonical_bytes(term()) :: binary()
  def canonical_bytes(json_like) do
    normalized = normalize(json_like)
    :erlang.term_to_binary(normalized, [:deterministic])
  end

  @doc """Compute SHA-256 hash (32 bytes)."""
  @spec sha256(binary()) :: binary()
  def sha256(bytes) when is_binary(bytes), do: :crypto.hash(:sha256, bytes)

  @doc """Compute content hash from a JSON-like term."""
  @spec content_hash(term()) :: binary()
  def content_hash(json_like) do
    json_like |> canonical_bytes() |> sha256()
  end

  @doc """Base64url (no padding) content id suitable for URLs."""
  @spec content_id(binary()) :: binary()
  def content_id(<<_::binary-size(32)>> = hash) do
    Base.url_encode64(hash, padding: false)
  end

  @doc """Decode base64url content id back to raw 32-byte hash."""
  @spec decode_content_id(binary()) :: {:ok, binary()} | {:error, term()}
  def decode_content_id(content_id) when is_binary(content_id) do
    case Base.url_decode64(content_id, padding: false) do
      {:ok, <<_::binary-size(32)>> = hash} -> {:ok, hash}
      {:ok, other} -> {:error, {:bad_length, byte_size(other)}}
      :error -> {:error, :bad_base64url}
    end
  end

  defp key_to_string(k) when is_binary(k), do: k
  defp key_to_string(k) when is_atom(k), do: Atom.to_string(k)
  defp key_to_string(k) when is_integer(k), do: Integer.to_string(k)
  defp key_to_string(k), do: to_string(k)
end
