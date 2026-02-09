defmodule PhaedrusDB.CLI do
  @moduledoc "Command-line client for a running PhaedrusDB HTTP server."

  @default_url "http://localhost:4007"

  def main(args) do
    case args do
      ["observe-ndjson", path | rest] ->
        {opts, _} = OptionParser.parse!(rest, strict: [url: :string, api_key: :string, mode: :string])
        url = opts[:url] || System.get_env("PHAEDRUS_URL") || @default_url
        api_key = opts[:api_key] || System.get_env("PHAEDRUS_API_KEY")
        mode = opts[:mode] || "ndjson"

        observe_ndjson(url, api_key, path, mode)

      ["recent" | rest] ->
        {opts, _} = OptionParser.parse!(rest, strict: [url: :string, api_key: :string, limit: :integer, source: :string, tag: :keep])
        url = opts[:url] || System.get_env("PHAEDRUS_URL") || @default_url
        api_key = opts[:api_key] || System.get_env("PHAEDRUS_API_KEY")
        params = opts_to_params(opts)

        r = Req.get!(url <> "/observations/recent", headers: headers(api_key), params: params)
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

    params =
      case opts[:tag] do
        nil -> params
        tags -> Map.put(params, "tag", List.wrap(tags))
      end

    params
  end

  defp usage do
    IO.puts("""
    PhaedrusDB CLI

    Commands:
      phaedrus_db observe-ndjson <path> [--url <baseUrl>] [--api-key <key>] [--mode ndjson|json]
      phaedrus_db recent [--url <baseUrl>] [--api-key <key>] [--limit N] [--source S] [--tag T --tag T]

    Env:
      PHAEDRUS_URL      Base URL (default #{@default_url})
      PHAEDRUS_API_KEY  API key (also used by server; for client this is sent as x-phaedrus-key)
    """)
  end
end
