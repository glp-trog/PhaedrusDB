defmodule PhaedrusDB.CLI do
  @moduledoc "Command-line client for a running PhaedrusDB HTTP server."

  @default_url "http://localhost:4007"

  def main(args) do
    # When running as an escript, applications may not be started automatically.
    # Req uses Finch + telemetry under the hood.
    _ = Application.ensure_all_started(:telemetry)
    _ = Application.ensure_all_started(:finch)
    _ = Application.ensure_all_started(:req)
    case args do
      ["observe-ndjson", path | rest] ->
        {opts, _} = OptionParser.parse!(rest, strict: [url: :string, api_key: :string, mode: :string])
        url = opts[:url] || System.get_env("PHAEDRUS_URL") || @default_url
        api_key = opts[:api_key] || System.get_env("PHAEDRUS_API_KEY")
        mode = opts[:mode] || "ndjson"

        observe_ndjson(url, api_key, path, mode)

      ["recent" | rest] ->
        {opts, _} =
          OptionParser.parse!(rest,
            strict: [
              url: :string,
              api_key: :string,
              limit: :integer,
              source: :string,
              tag: :keep,
              since: :string,
              before: :string
            ]
          )

        url = opts[:url] || System.get_env("PHAEDRUS_URL") || @default_url
        api_key = opts[:api_key] || System.get_env("PHAEDRUS_API_KEY")
        params = opts_to_params(opts)

        r = Req.get!(url <> "/observations/recent", headers: headers(api_key), params: params)
        IO.puts(Jason.encode!(r.body, pretty: true))

      ["bundle", content_id | rest] ->
        {opts, _} = OptionParser.parse!(rest, strict: [url: :string, api_key: :string, out: :string, limit: :integer])
        url = opts[:url] || System.get_env("PHAEDRUS_URL") || @default_url
        api_key = opts[:api_key] || System.get_env("PHAEDRUS_API_KEY")
        limit = opts[:limit] || 20

        r = Req.get!(url <> "/bundle/" <> content_id, headers: headers(api_key), params: %{limit: limit})
        json = Jason.encode!(r.body, pretty: true)

        if is_binary(opts[:out]) do
          File.write!(opts[:out], json <> "\n")
        else
          IO.puts(json)
        end

      ["verify-receipt", path | rest] ->
        {opts, _} = OptionParser.parse!(rest, strict: [url: :string, api_key: :string])
        url = opts[:url] || System.get_env("PHAEDRUS_URL") || @default_url
        api_key = opts[:api_key] || System.get_env("PHAEDRUS_API_KEY")

        receipt = Jason.decode!(File.read!(path))
        {cid, pub_b64, sig_b64} = extract_receipt(receipt)

        r =
          Req.post!(
            url <> "/verify",
            headers: headers(api_key) ++ [{"content-type", "application/json"}],
            json: %{content_id: cid, pubkey_b64: pub_b64, sig_b64: sig_b64}
          )

        IO.puts(Jason.encode!(r.body, pretty: true))

      _ ->
        usage()
        System.halt(2)
    end
  end

  defp observe_ndjson(base_url, api_key, path, mode) do
    unless File.exists?(path) do
      IO.puts(:stderr, "File not found: #{path}")
      System.halt(2)
    end

    body = File.read!(path)

    r =
      Req.post!(
        base_url <> "/observe/ndjson",
        headers: headers(api_key) ++ [{"content-type", "application/x-ndjson"}],
        params: %{mode: mode},
        body: body,
        receive_timeout: 120_000
      )

    ct = List.first(r.headers["content-type"] || [])

    if is_binary(ct) and String.contains?(ct, "application/x-ndjson") do
      IO.write(r.body)
    else
      IO.puts(Jason.encode!(r.body, pretty: true))
    end
  end

  defp headers(nil), do: []
  defp headers(key), do: [{"x-phaedrus-key", key}]

  defp opts_to_params(opts) do
    params = %{}
    params = if opts[:limit], do: Map.put(params, "limit", opts[:limit]), else: params
    params = if opts[:source], do: Map.put(params, "source", opts[:source]), else: params
    params = if opts[:since], do: Map.put(params, "since", opts[:since]), else: params
    params = if opts[:before], do: Map.put(params, "before", opts[:before]), else: params

    params =
      case opts[:tag] do
        nil -> params
        tags -> Map.put(params, "tag", List.wrap(tags))
      end

    params
  end

  defp extract_receipt(map) when is_map(map) do
    cid = map["content_id"] || get_in(map, ["proof", "content_id"])

    pub_b64 =
      map["pubkey_b64"] ||
        get_in(map, ["proof", "pubkey_b64"]) ||
        get_in(map, ["entry", "pubkey_b64"]) ||
        get_in(map, ["entry", "proof", "pubkey_b64"])

    sig_b64 =
      map["sig_b64"] ||
        get_in(map, ["proof", "sig_b64"]) ||
        get_in(map, ["entry", "sig_b64"]) ||
        get_in(map, ["entry", "proof", "sig_b64"])

    if is_binary(cid) and is_binary(pub_b64) and is_binary(sig_b64) do
      {cid, pub_b64, sig_b64}
    else
      raise "receipt missing required fields (content_id, pubkey_b64, sig_b64)"
    end
  end

  defp usage do
    IO.puts("""
    PhaedrusDB CLI

    Commands:
      phaedrus_db observe-ndjson <path> [--url <baseUrl>] [--api-key <key>] [--mode ndjson|json]
      phaedrus_db recent [--url <baseUrl>] [--api-key <key>] [--limit N] [--source S] [--tag T --tag T] [--since ISO] [--before ISO]
      phaedrus_db bundle <content_id> [--url <baseUrl>] [--api-key <key>] [--limit N] [--out bundle.json]
      phaedrus_db verify-receipt <path.json> [--url <baseUrl>] [--api-key <key>]

    Env:
      PHAEDRUS_URL      Base URL (default #{@default_url})
      PHAEDRUS_API_KEY  API key (also used by server; for client this is sent as x-phaedrus-key)
    """)
  end
end
