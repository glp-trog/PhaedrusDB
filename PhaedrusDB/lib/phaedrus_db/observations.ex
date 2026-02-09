defmodule PhaedrusDB.Observations do
  @moduledoc """
  Timeline / sightings layer for PhaedrusDB entries.

  An observation points at an immutable entry via its `content_hash`.
  """

  import Ecto.Query, warn: false

  alias PhaedrusDB.{CryptoId, Observation, Repo}

  @doc "Create an observation for a content_id." 
  def observe(content_id, attrs) when is_map(attrs) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id) do
      attrs2 =
        attrs
        |> Map.put_new("observed_at", DateTime.utc_now() |> DateTime.truncate(:second))
        |> Map.put("content_hash", hash)

      %Observation{}
      |> Observation.changeset(attrs2)
      |> Repo.insert()
    end
  end

  @doc "Convenience: put (optionally sign) a payload, then observe it." 
  def observe_payload(payload, sign?, attrs) when is_map(attrs) do
    put_res = if sign?, do: PhaedrusDB.put_and_sign(payload), else: PhaedrusDB.put(payload)

    with {:ok, res} <- put_res,
         {:ok, obs} <- observe(res.content_id, attrs) do
      {:ok, %{content_id: res.content_id, entry: Map.get(res, :entry), proof: build_proof(res), observation: obs}}
    end
  end

  defp build_proof(%{entry: entry, content_id: content_id}) do
    %{"content_id" => content_id, "pubkey_b64" => b64(entry.pubkey), "sig_b64" => b64(entry.sig)}
  end

  defp build_proof(_), do: nil

  defp b64(nil), do: nil
  defp b64(bin) when is_binary(bin), do: Base.encode64(bin)

  @doc "List observations for a content_id (newest first)." 
  def list_for(content_id, limit \\ 50) do
    with {:ok, hash} <- CryptoId.decode_content_id(content_id) do
      q =
        from o in Observation,
          where: o.content_hash == ^hash,
          order_by: [desc: o.observed_at, desc: o.inserted_at],
          limit: ^limit

      {:ok, Repo.all(q)}
    end
  end

  @doc "List recent observations across all content (newest first)." 
  def list_recent(opts \\ %{}) when is_map(opts) do
    limit = opts_limit(opts)

    q =
      from o in Observation,
        order_by: [desc: o.observed_at, desc: o.inserted_at],
        limit: ^limit

    q =
      case opts["source"] do
        s when is_binary(s) and byte_size(s) > 0 -> from o in q, where: o.source == ^s
        _ -> q
      end

    q =
      case opts["tag"] do
        tags when is_list(tags) ->
          tags = tags |> Enum.filter(&is_binary/1) |> Enum.map(&String.trim/1) |> Enum.filter(&(byte_size(&1) > 0))

          Enum.reduce(tags, q, fn t, acc ->
            from o in acc, where: ^t in o.tags
          end)

        t when is_binary(t) and byte_size(t) > 0 ->
          from o in q, where: ^t in o.tags

        _ ->
          q
      end

    q =
      case opts["since"] do
        s when is_binary(s) and byte_size(s) > 0 ->
          case DateTime.from_iso8601(s) do
            {:ok, dt, _} -> from o in q, where: o.observed_at >= ^dt
            _ -> q
          end

        _ -> q
      end

    q =
      case opts["before"] do
        s when is_binary(s) and byte_size(s) > 0 ->
          case DateTime.from_iso8601(s) do
            {:ok, dt, _} -> from o in q, where: o.observed_at < ^dt
            _ -> q
          end

        _ -> q
      end

    {:ok, Repo.all(q)}
  end

  @doc "Top sources by observation count." 
  def top_sources(opts \\ %{}) when is_map(opts) do
    limit = opts_limit(opts)

    base = from o in Observation

    base =
      case opts["since"] do
        s when is_binary(s) and byte_size(s) > 0 ->
          case DateTime.from_iso8601(s) do
            {:ok, dt, _} -> from o in base, where: o.observed_at >= ^dt
            _ -> base
          end

        _ -> base
      end

    q =
      from o in base,
        group_by: o.source,
        select: %{source: o.source, count: count(o.id), last_observed_at: max(o.observed_at)},
        order_by: [desc: count(o.id)],
        limit: ^limit

    {:ok, Repo.all(q)}
  end

  defp opts_limit(opts) do
    limit =
      case opts["limit"] do
        n when is_integer(n) -> n
        s when is_binary(s) ->
          case Integer.parse(s) do
            {n, _} -> n
            :error -> 50
          end

        _ -> 50
      end

    limit
    |> min(200)
    |> max(1)
  end
end
