defmodule PhaedrusDB.BundleEndpointTest do
  use PhaedrusDB.DataCase, async: false

  test "GET /bundle/:content_id returns payload + proof + observations" do
    {:ok, res} = PhaedrusDB.put_and_sign(%{"kind" => "claim", "x" => 1})

    {:ok, _obs} =
      PhaedrusDB.observe(res.content_id, %{
        "source" => "t",
        "url" => "https://example.com",
        "tags" => ["demo"],
        "observed_at" => ~U[2026-02-09 12:00:00Z]
      })

    conn = Plug.Test.conn(:get, "/bundle/#{res.content_id}?limit=5")
    conn = PhaedrusDB.Web.Router.call(conn, [])

    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)

    assert body["content_id"] == res.content_id
    assert body["entry"]["payload"]["kind"] == "claim"
    assert is_binary(body["proof"]["pubkey_b64"])
    assert is_binary(body["proof"]["sig_b64"])
    assert is_list(body["observations"])
    assert length(body["observations"]) == 1
    assert hd(body["observations"])["url"] == "https://example.com"
  end
end
