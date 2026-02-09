defmodule PhaedrusDB.ObservationsTest do
  use PhaedrusDB.DataCase, async: false

  test "observe + list_for" do
    {:ok, res} = PhaedrusDB.put(%{"x" => 1})

    {:ok, obs} =
      PhaedrusDB.observe(res.content_id, %{
        "source" => "unit-test",
        "url" => "https://example.com/thing",
        "tags" => ["alpha", "beta"],
        "meta" => %{"k" => "v"}
      })

    assert obs.source == "unit-test"

    {:ok, items} = PhaedrusDB.observations(res.content_id)
    assert length(items) >= 1
    assert Enum.any?(items, fn o -> o.id == obs.id end)
  end
end
