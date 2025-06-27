defmodule DimensionForge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Only load .env in development/test environments, not in production releases
    if Application.get_env(:dimension_forge, :load_dotenv, false) do
      Dotenv.load()
    end

    children = [
      DimensionForgeWeb.Telemetry,
      DimensionForge.Repo,
      {DNSCluster, query: Application.get_env(:dimension_forge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DimensionForge.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DimensionForge.Finch},
      # Start Goth for Google Cloud authentication
      {Goth, name: DimensionForge.Goth, source: goth_source()},
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

  defp goth_source do
    cond do
      # Use explicit service account credentials if provided
      System.get_env("GOOGLE_APPLICATION_CREDENTIALS") ->
        {:service_account, gcp_credentials_from_file()}

      # Use explicit JSON credentials if provided
      System.get_env("GCP_CREDENTIALS_JSON") ->
        {:service_account, gcp_credentials_from_env()}

      # Use default Cloud Run service account (metadata server)
      true ->
        {:metadata, []}
    end
  end

  defp gcp_credentials_from_file do
    path = System.get_env("GOOGLE_APPLICATION_CREDENTIALS")
    case File.read(path) do
      {:ok, json} -> Jason.decode!(json)
      {:error, _} -> raise "Could not read GCP credentials from #{path}"
    end
  end

  defp gcp_credentials_from_env do
    credentials_path = System.get_env("GCP_CREDENTIALS_JSON")
    case File.read(credentials_path) do
      {:ok, json} -> Jason.decode!(json)
      {:error, _} -> raise "Could not read GCP credentials from #{credentials_path}"
    end
  end
end
