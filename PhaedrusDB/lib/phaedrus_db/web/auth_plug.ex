defmodule PhaedrusDB.Web.AuthPlug do
  @moduledoc """
  Optional API key auth.

  If `PHAEDRUS_API_KEY` is set, requests must include one of:
  - `x-phaedrus-key: <key>`
  - `authorization: Bearer <key>`

  If `PHAEDRUS_API_KEY` is not set, auth is disabled.

  `/health` is always allowed.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/health"} = conn, _opts), do: conn

  def call(conn, _opts) do
    case System.get_env("PHAEDRUS_API_KEY") do
      nil ->
        conn

      expected when is_binary(expected) and byte_size(expected) > 0 ->
        provided =
          get_req_header(conn, "x-phaedrus-key") |> first_nonempty() ||
            bearer_token(get_req_header(conn, "authorization"))

        if provided == expected do
          conn
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(401, Jason.encode!(%{error: "unauthorized"}))
          |> halt()
        end
    end
  end

  defp first_nonempty([h | _]) when is_binary(h) and byte_size(h) > 0, do: h
  defp first_nonempty(_), do: nil

  defp bearer_token([h | _]) do
    h = String.trim(h)

    case String.split(h, ~r/\s+/, parts: 2) do
      ["Bearer", token] -> token
      _ -> nil
    end
  end

  defp bearer_token(_), do: nil
end
