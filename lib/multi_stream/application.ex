defmodule MultiStream.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: MultiStream.Router, options: [port: 4002]}

      # Starts a worker by calling: MultiStream.Worker.start_link(arg)
      # {MultiStream.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MultiStream.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
