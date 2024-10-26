defmodule PhaedrusDB.ExampleModel do
  use Ecto.Schema

  schema "example_model" do
    field :data, :string
    field :timestamp, :naive_datetime
  end
end
