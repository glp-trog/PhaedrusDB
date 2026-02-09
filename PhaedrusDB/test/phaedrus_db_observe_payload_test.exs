defmodule PhaedrusDB.ObservePayloadTest do
  use PhaedrusDB.DataCase, async: false

  test "observe_payload signs and returns proof" do
    key_path = Path.join(System.tmp_dir!(), "phaedrus_key_test_#{System.unique_integer([:positive])}.json")

    try do
      System.put_env("PHAEDRUS_KEY_PATH", key_path)

      {:ok, res} =
        PhaedrusDB.Observations.observe_payload(
          %{"hello" => "world"},
          true,
          %{"source" => "unit-test", "url" => "https://example.com"}
        )

      assert is_binary(res.content_id)
      assert is_map(res.proof)
      assert res.proof["content_id"] == res.content_id
      assert is_binary(res.proof["pubkey_b64"])
      assert is_binary(res.proof["sig_b64"])
      assert res.observation.source == "unit-test"
    after
      System.delete_env("PHAEDRUS_KEY_PATH")
      File.rm(key_path)
    end
  end
end
