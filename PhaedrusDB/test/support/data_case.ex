defmodule PhaedrusDB.DataCase do
  @moduledoc """Test helpers for working with the database."""

  use ExUnit.CaseTemplate

  using do
    quote do
      alias PhaedrusDB.Repo
      import Ecto
      import Ecto.Query
      import PhaedrusDB.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PhaedrusDB.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(PhaedrusDB.Repo, {:shared, self()})
    end

    :ok
  end
end
