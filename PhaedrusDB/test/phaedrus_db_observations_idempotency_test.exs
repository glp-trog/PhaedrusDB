defmodule PhaedrusDB.ObservationsIdempotencyTest do
  use PhaedrusDB.DataCase, async: false

  test "observe is idempotent for same (content_id, source, url, observed_at)" do
    {:ok, res} = PhaedrusDB.put(%{"x" => 1})

    attrs = %{
      "source" => "idem",
      "url" => "https://example.com/1",
      "observed_at" => ~U[2026-02-09 12:00:00Z]
    }

    {:ok, obs1} = PhaedrusDB.observe(res.content_id, attrs)
    {:ok, obs2} = PhaedrusDB.observe(res.content_id, attrs)

    assert obs1.id == obs2.id

    {:ok, items} = PhaedrusDB.observations(res.content_id)
    assert Enum.count(items, fn o -> o.source == "idem" and o.url == "https://example.com/1" end) == 1
  end
end
