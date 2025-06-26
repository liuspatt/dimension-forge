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
      # Start Goth for Google Cloud authentication
      {Goth, name: DimensionForge.Goth, source: {:service_account, gcp_credentials(), []}},
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

  defp gcp_credentials do
    case System.get_env("GOOGLE_APPLICATION_CREDENTIALS") do
      nil ->
        # Fallback to project credentials file
        credentials_path = case System.get_env("GCP_CREDENTIALS_JSON") do
          nil -> Path.join([File.cwd!(), "credentials.json"])
          path -> Path.join([File.cwd!(), path])
        end

        case File.read(credentials_path) do
          {:ok, json} ->
            Jason.decode!(json)

          {:error, _} ->
            raise "GCP credentials not found. Set GOOGLE_APPLICATION_CREDENTIALS or provide #{credentials_path}"
        end

      path ->
        case File.read(path) do
          {:ok, json} -> Jason.decode!(json)
          {:error, _} -> raise "Could not read GCP credentials from #{path}"
        end
    end
  end
end
