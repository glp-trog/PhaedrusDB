defmodule PhaedrusDB.Web.Router do
  @moduledoc "HTTP API for PhaedrusDB (minimal)."

  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/x-ndjson"],
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

  # POST /observe/ndjson (stream/batch)
  # Content-Type: application/x-ndjson
  # Body: one JSON object per line. Each line can be the same shape accepted by POST /observe.
  post "/observe/ndjson" do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)

    lines =
      body
      |> String.split(["\n", "\r\n"], trim: true)
      |> Enum.reject(&(&1 == ""))

    {results, ok_count, err_count} =
      Enum.reduce(Enum.with_index(lines, 1), {[], 0, 0}, fn {line, idx}, {acc, okc, errc} ->
        case Jason.decode(line) do
          {:ok, params} when is_map(params) ->
            case handle_observe_params(params) do
              {:ok, res} ->
                {[Map.put(res, :line, idx) | acc], okc + 1, errc}

              {:error, reason} ->
                {[%{line: idx, ok: false, error: format_reason(reason)} | acc], okc, errc + 1}
            end

          {:ok, _} ->
            {[%{line: idx, ok: false, error: "expected_object"} | acc], okc, errc + 1}

          {:error, _} ->
            {[%{line: idx, ok: false, error: "bad_json"} | acc], okc, errc + 1}
        end
      end)

    results = Enum.reverse(results)

    send_json(conn, 200, %{ok: err_count == 0, ingested: ok_count, errors: err_count, results: results})
  end

  # POST /observe
  # Either:
  # - {"content_id":"...","source":"...", ...}
  # or:
  # - {"payload":{...},"sign":true|false,"source":"...", ...}
  post "/observe" do
    params = conn.body_params

    case handle_observe_params(params) do
      {:ok, res} ->
        send_json(conn, 200, res)

      {:error, %Ecto.Changeset{} = cs} ->
        send_json(conn, 400, %{error: "invalid", details: format_changeset(cs)})

      {:error, reason} ->
        send_json(conn, 400, %{error: format_reason(reason)})
    end
  end

  # GET /observations/recent?source=...&tag=...&since=...&before=...&limit=...
  # IMPORTANT: this must be defined before /observations/:content_id
  get "/observations/recent" do
    case PhaedrusDB.observations_recent(conn.params) do
      {:ok, items} ->
        next_before =
          case List.last(items) do
            nil -> nil
            last -> last.observed_at
          end

        send_json(conn, 200, %{observations: Enum.map(items, &obs_json/1), next_before: next_before})

      {:error, reason} ->
        send_json(conn, 400, %{error: inspect(reason)})
    end
  end

  # GET /sources?since=...&limit=...
  get "/sources" do
    case PhaedrusDB.sources(conn.params) do
      {:ok, items} ->
        send_json(conn, 200, %{sources: items})

      {:error, reason} ->
        send_json(conn, 400, %{error: inspect(reason)})
    end
  end

  # GET /observations/:content_id
  get "/observations/:content_id" do
    limit = (conn.params["limit"] || "50") |> to_int(50) |> min(200) |> max(1)

    case PhaedrusDB.observations(content_id, limit) do
      {:ok, items} ->
        send_json(conn, 200, %{content_id: content_id, observations: Enum.map(items, &obs_json/1)})

      {:error, reason} ->
        send_json(conn, 400, %{error: inspect(reason)})
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

  defp obs_json(o) do
    %{
      id: o.id,
      content_id: PhaedrusDB.CryptoIdHelpers.content_id_from_hash(o.content_hash),
      source: o.source,
      observed_at: o.observed_at,
      url: o.url,
      notes: o.notes,
      tags: o.tags,
      meta: o.meta,
      inserted_at: o.inserted_at
    }
  end

  defp to_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> default
    end
  end

  defp format_changeset(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end

  defp handle_observe_params(params) when is_map(params) do
    cond do
      is_map(params["payload"]) and is_binary(params["source"]) ->
        payload = params["payload"]
        sign? = params["sign"] == true
        attrs = Map.drop(params, ["payload", "sign"])

        case PhaedrusDB.Observations.observe_payload(payload, sign?, attrs) do
          {:ok, res} ->
            {:ok, %{content_id: res.content_id, proof: res.proof, observation: obs_json(res.observation)}}

          {:error, _} = err ->
            err
        end

      is_binary(params["content_id"]) and is_binary(params["source"]) ->
        cid = params["content_id"]

        case PhaedrusDB.observe(cid, params) do
          {:ok, obs} -> {:ok, %{id: obs.id, content_id: cid, source: obs.source, observed_at: obs.observed_at, url: obs.url, tags: obs.tags}}
          {:error, _} = err -> err
        end

      true ->
        {:error, :bad_params}
    end
  end

  defp format_reason(:bad_params), do: "Expected JSON body: {content_id, source, ...} OR {payload, sign?, source, ...}"
  defp format_reason(other), do: inspect(other)
end
