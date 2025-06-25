defmodule DimensionForge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    unless Mix.env() == :prod do
      Dotenv.load()
      Mix.Task.run("loadconfig")
    end
    children = [
      DimensionForgeWeb.Telemetry,
      DimensionForge.Repo,
      {DNSCluster, query: Application.get_env(:dimension_forge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DimensionForge.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DimensionForge.Finch},
      # Start a worker by calling: DimensionForge.Worker.start_link(arg)
      # {DimensionForge.Worker, arg},
      # Start to serve requests, typically the last entry
      DimensionForgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DimensionForge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DimensionForgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
