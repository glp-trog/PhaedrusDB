defmodule PhaedrusDB.ObservationsRecentTest do
  use PhaedrusDB.DataCase, async: false

  test "list_recent supports source filter" do
    {:ok, a} = PhaedrusDB.put(%{"a" => 1})
    {:ok, b} = PhaedrusDB.put(%{"b" => 2})

    {:ok, _} = PhaedrusDB.observe(a.content_id, %{"source" => "s1"})
    {:ok, _} = PhaedrusDB.observe(b.content_id, %{"source" => "s2"})

    {:ok, s1} = PhaedrusDB.observations_recent(%{"source" => "s1", "limit" => 50})
    assert Enum.all?(s1, fn o -> o.source == "s1" end)
  end
end
