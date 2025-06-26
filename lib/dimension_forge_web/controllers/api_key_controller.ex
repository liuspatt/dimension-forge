defmodule DimensionForgeWeb.ApiKeyController do
  use DimensionForgeWeb, :controller

  alias DimensionForge.ApiKeys

  action_fallback(DimensionForgeWeb.FallbackController)

  def validate(conn, %{"key" => key}) do
    case ApiKeys.validate_api_key(key) do
      {:ok, api_key} ->
        conn
        |> put_status(:ok)
        |> json(%{valid: true, name: api_key.name, id: api_key.id})

      {:error, :invalid_key} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{valid: false, error: "Invalid API key"})
    end
  end

  def validate(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{valid: false, error: "API key parameter is required"})
  end
end
