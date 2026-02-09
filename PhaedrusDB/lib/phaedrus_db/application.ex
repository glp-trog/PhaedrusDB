defmodule PhaedrusDB.Application do
  use Application

  def start(_type, _args) do
    children =
      [PhaedrusDB.Repo]
      |> maybe_add_http()

    opts = [strategy: :one_for_one, name: PhaedrusDB.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Don’t start the HTTP server in test.
  defp maybe_add_http(children) do
    if Mix.env() == :test do
      children
    else
      children ++
        [
          {Plug.Cowboy,
           scheme: :http, plug: PhaedrusDB.Web.Router, options: [port: http_port()]}
        ]
    end
  end

  defp http_port do
    System.get_env("PHAEDRUS_HTTP_PORT", "4007") |> String.to_integer()
  end
end
