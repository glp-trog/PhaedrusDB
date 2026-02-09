defmodule PhaedrusDB.Web.Router do
  @moduledoc "HTTP API for PhaedrusDB (minimal)."

  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    body_reader: {PhaedrusDB.Web.BodyReader, :read_body, []}

  plug :dispatch

  get "/health" do
    send_json(conn, 200, %{ok: true, service: "phaedrus_db"})
  end

  # POST /entries {"payload": { ...json... }}
  post "/entries" do
    with %{"payload" => payload} <- conn.body_params,
         {:ok, res} <- PhaedrusDB.put(payload) do
      send_json(conn, 200, %{content_id: res.content_id})
    else
      _ -> send_json(conn, 400, %{error: "Expected JSON body: {payload: <json>}"})
    end
  end

  # GET /entries/:content_id
  get "/entries/:content_id" do
    case PhaedrusDB.get(content_id) do
      {:ok, entry} ->
        send_json(conn, 200, %{content_id: content_id, payload: entry.payload, inserted_at: entry.inserted_at})

      {:error, :not_found} ->
        send_json(conn, 404, %{error: "not_found"})

      {:error, reason} ->
        send_json(conn, 400, %{error: inspect(reason)})
    end
  end

  # POST /entries/:content_id/sign
  post "/entries/:content_id/sign" do
    case PhaedrusDB.sign(content_id) do
      {:ok, entry} ->
        send_json(conn, 200, %{content_id: content_id, pubkey_b64: b64(entry.pubkey), sig_b64: b64(entry.sig)})

      {:error, :not_found} ->
        send_json(conn, 404, %{error: "not_found"})

      {:error, reason} ->
        send_json(conn, 400, %{error: inspect(reason)})
    end
  end

  # POST /entries/:content_id/verify
  post "/entries/:content_id/verify" do
    case PhaedrusDB.verify(content_id) do
      {:ok, ok?} -> send_json(conn, 200, %{content_id: content_id, ok: ok?})
      {:error, :unsigned} -> send_json(conn, 400, %{error: "unsigned"})
      {:error, :not_found} -> send_json(conn, 404, %{error: "not_found"})
      {:error, reason} -> send_json(conn, 400, %{error: inspect(reason)})
    end
  end

  match _ do
    send_json(conn, 404, %{error: "not_found"})
  end

  defp send_json(conn, status, map) do
    body = Jason.encode!(map)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  defp b64(nil), do: nil
  defp b64(bin) when is_binary(bin), do: Base.encode64(bin)
end
