defmodule PhaedrusDB.ObservationsPaginationTest do
  use PhaedrusDB.DataCase, async: false

  test "recent supports before pagination" do
    {:ok, a} = PhaedrusDB.put(%{"a" => 1})

    # create 3 observations with controlled observed_at
    {:ok, _} = PhaedrusDB.observe(a.content_id, %{"source" => "p", "observed_at" => ~U[2026-02-09 10:00:00Z]})
    {:ok, _} = PhaedrusDB.observe(a.content_id, %{"source" => "p", "observed_at" => ~U[2026-02-09 11:00:00Z]})
    {:ok, _} = PhaedrusDB.observe(a.content_id, %{"source" => "p", "observed_at" => ~U[2026-02-09 12:00:00Z]})

    {:ok, page1} = PhaedrusDB.observations_recent(%{"source" => "p", "limit" => 2})
    assert length(page1) == 2
    assert Enum.at(page1, 0).observed_at >= Enum.at(page1, 1).observed_at

    before = List.last(page1).observed_at |> DateTime.to_iso8601()

    {:ok, page2} = PhaedrusDB.observations_recent(%{"source" => "p", "limit" => 10, "before" => before})
    assert length(page2) == 1
  end
end
