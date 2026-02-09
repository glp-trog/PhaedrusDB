defmodule PhaedrusDB.CryptoIdHelpers do
  @moduledoc false

  # Helpers to keep base64url content_id encoding consistent.

  def content_id_from_hash(<<_::binary-size(32)>> = hash) do
    Base.url_encode64(hash, padding: false)
  end
end
