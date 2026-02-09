defmodule PhaedrusDB.EntriesFlowTest do
  use PhaedrusDB.DataCase, async: false

  test "put -> sign -> verify (db) -> verify (detached)" do
    key_path = Path.join(System.tmp_dir!(), "phaedrus_key_test_#{System.unique_integer([:positive])}.json")

    try do
      # isolate key file for test
      System.put_env("PHAEDRUS_KEY_PATH", key_path)

      {:ok, res} = PhaedrusDB.put(%{"hello" => "world", "n" => 1})

      {:ok, signed} = PhaedrusDB.sign(res.content_id)
      assert is_binary(signed.pubkey) and byte_size(signed.pubkey) == 32
      assert is_binary(signed.sig) and byte_size(signed.sig) == 64

      assert {:ok, true} == PhaedrusDB.verify(res.content_id)
      assert {:ok, true} == PhaedrusDB.verify_detached(res.content_id, signed.pubkey, signed.sig)

      # wrong content_id must fail
      {:ok, other} = PhaedrusDB.put(%{"hello" => "WORLD", "n" => 1})
      assert {:ok, false} == PhaedrusDB.verify_detached(other.content_id, signed.pubkey, signed.sig)
    after
      System.delete_env("PHAEDRUS_KEY_PATH")
      File.rm(key_path)
    end
  end
end
