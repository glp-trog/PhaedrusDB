defmodule PhaedrusDB.Web.BodyReader do
  @moduledoc false

  # Prevent huge payloads from being read into memory accidentally.
  @max_bytes 1_000_000

  def read_body(conn, opts) do
    Plug.Conn.read_body(conn, Keyword.put_new(opts, :length, @max_bytes))
  end
end
