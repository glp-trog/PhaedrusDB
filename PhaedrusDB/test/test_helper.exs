ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(PhaedrusDB.Repo, :manual)
Code.require_file("support/data_case.exs", __DIR__)
