defmodule PhaedrusDBTest do
  use PhaedrusDB.DataCase, async: true
  doctest PhaedrusDB

  test "ping" do
    assert PhaedrusDB.ping() == :pong
  end
end
