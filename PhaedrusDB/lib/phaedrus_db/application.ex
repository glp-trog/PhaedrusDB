defmodule PhaedrusDB.Application do
  use Application

  def start(_type, _args) do
    children = [
      PhaedrusDB.Repo
    ]

    opts = [strategy: :one_for_one, name: PhaedrusDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
