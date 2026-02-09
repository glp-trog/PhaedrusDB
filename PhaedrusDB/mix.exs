defmodule PhaedrusDB.MixProject do
  use Mix.Project

  def project do
    [
      app: :phaedrus_db,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  defp escript do
    [
      main_module: PhaedrusDB.CLI,
      app: nil
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PhaedrusDB.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.7"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:rustler, "~> 0.36"},
      {:req, "~> 0.5"}
    ]
  end
end
