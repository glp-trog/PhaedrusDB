defmodule PhaedrusDB.NdjsonIngestTest do
  use PhaedrusDB.DataCase, async: false

  test "observe_ndjson ingests multiple lines" do
    payload1 = %{payload: %{"x" => 1}, sign: false, source: "nd", url: "https://a"}
    payload2 = %{payload: %{"x" => 2}, sign: true, source: "nd", url: "https://b"}

    body =
      Jason.encode!(payload1) <> "\n" <>
        Jason.encode!(payload2) <> "\n"

    # call router helper directly
    conn =
      Plug.Test.conn(:post, "/observe/ndjson", body)
      |> Plug.Conn.put_req_header("content-type", "application/x-ndjson")

    conn = PhaedrusDB.Web.Router.call(conn, [])

    assert conn.status == 200

    resp = Jason.decode!(conn.resp_body)
    assert resp["ok"] == true
    assert resp["ingested"] == 2
    assert is_list(resp["results"])
    assert length(resp["results"]) == 2

    # ndjson response mode
    conn2 =
      Plug.Test.conn(:post, "/observe/ndjson?mode=ndjson", body)
      |> Plug.Conn.put_req_header("content-type", "application/x-ndjson")

    conn2 = PhaedrusDB.Web.Router.call(conn2, [])
    assert conn2.status == 200
    assert Plug.Conn.get_resp_header(conn2, "content-type") |> Enum.any?(&String.contains?(&1, "application/x-ndjson"))

    lines = String.split(conn2.resp_body, ["\n", "\r\n"], trim: true)
    assert length(lines) == 3
    summary = Jason.decode!(Enum.at(lines, 0))
    assert summary["ingested"] == 2
  end
end
