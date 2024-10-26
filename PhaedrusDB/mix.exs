defmodule PhaedrusDB.MixProject do
  use Mix.Project

  def project do
    [
      app: :phaedrus_db,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PhaedrusDB.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.7"},
      {:postgrex, ">= 0.0.0"} # for Postgres if we want it as an option
    ]
  end
end
