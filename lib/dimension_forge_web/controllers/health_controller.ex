defmodule DimensionForgeWeb.HealthController do
  use DimensionForgeWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{
      alive: true,
      service: "Dimension Forge - Image Proxy Service",
      version: "1.0.0",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
