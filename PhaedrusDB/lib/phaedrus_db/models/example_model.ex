defmodule PhaedrusDB.ExampleModel do
  use Ecto.Schema

  @moduledoc "Example schema used for smoke tests."

  schema "example_models" do
    field :data, :string
    field :timestamp, :naive_datetime

    timestamps()
  end
end
