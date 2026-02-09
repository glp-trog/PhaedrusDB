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

  # POST /entries {"payload": { ...json... }, "sign": true|false }
  post "/entries" do
    payload = conn.body_params["payload"]
    sign? = conn.body_params["sign"] == true

    cond do
      is_nil(payload) ->
        send_json(conn, 400, %{error: "Expected JSON body: {payload: <json>, sign?: boolean}"})

      sign? ->
        case PhaedrusDB.put_and_sign(payload) do
          {:ok, res} ->
            send_json(conn, 200, %{content_id: res.content_id, proof: proof(res.content_id, res.entry)})

          {:error, reason} ->
            send_json(conn, 400, %{error: inspect(reason)})
        end

      true ->
        case PhaedrusDB.put(payload) do
          {:ok, res} -> send_json(conn, 200, %{content_id: res.content_id})
          {:error, reason} -> send_json(conn, 400, %{error: inspect(reason)})
        end
    end
  end

  # GET /entries/:content_id
  get "/entries/:content_id" do
    case PhaedrusDB.get(content_id) do
      {:ok, entry} ->
        send_json(conn, 200, %{content_id: content_id, payload: entry.payload, inserted_at: entry.inserted_at, pubkey_b64: b64(entry.pubkey), sig_b64: b64(entry.sig), proof: proof(content_id, entry)})

      {:error, :not_found} ->
        send_json(conn, 404, %{error: "not_found"})

      {:error, reason} ->
        send_json(conn, 400, %{error: inspect(reason)})
    end
  end

  # GET /proof/:content_id (no payload)
  get "/proof/:content_id" do
    case PhaedrusDB.get(content_id) do
      {:ok, entry} ->
        send_json(conn, 200, %{content_id: content_id, proof: proof(content_id, entry)})

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

  # POST /verify {"content_id":"...","pubkey_b64":"...","sig_b64":"..."}
  post "/verify" do
    with %{"content_id" => cid, "pubkey_b64" => pub_b64, "sig_b64" => sig_b64} <- conn.body_params,
         {:ok, pub} <- b64d(pub_b64),
         {:ok, sig} <- b64d(sig_b64),
         {:ok, ok?} <- PhaedrusDB.verify_detached(cid, pub, sig) do
      send_json(conn, 200, %{content_id: cid, ok: ok?})
    else
      _ -> send_json(conn, 400, %{error: "Expected JSON body: {content_id,pubkey_b64,sig_b64}"})
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

  defp b64d(s) when is_binary(s) do
    case Base.decode64(s) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, :bad_base64}
    end
  end

  defp proof(content_id, entry) do
    # single blob for copy/paste sharing
    %{
      "content_id" => content_id,
      "pubkey_b64" => b64(entry.pubkey),
      "sig_b64" => b64(entry.sig)
    }
  end
end
