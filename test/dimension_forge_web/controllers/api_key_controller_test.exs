defmodule DimensionForgeWeb.ApiKeyControllerTest do
  use DimensionForgeWeb.ConnCase

  alias DimensionForge.ApiKeys

  describe "POST /api/validate-key" do
    test "returns valid response for active API key", %{conn: conn} do
      {:ok, api_key} = ApiKeys.create_api_key(%{"name" => "Test API"})
      
      conn = post(conn, ~p"/api/validate-key", %{"key" => api_key.key})
      
      assert %{
        "valid" => true,
        "name" => "Test API",
        "id" => _id
      } = json_response(conn, 200)
    end

    test "returns invalid response for non-existent API key", %{conn: conn} do
      conn = post(conn, ~p"/api/validate-key", %{"key" => "invalid_key"})
      
      assert %{
        "valid" => false,
        "error" => "Invalid API key"
      } = json_response(conn, 401)
    end

    test "returns invalid response for inactive API key", %{conn: conn} do
      {:ok, api_key} = ApiKeys.create_api_key(%{"name" => "Test API"})
      
      # Manually set key as inactive
      api_key
      |> DimensionForge.ApiKey.changeset(%{"active" => false})
      |> DimensionForge.Repo.update!()
      
      conn = post(conn, ~p"/api/validate-key", %{"key" => api_key.key})
      
      assert %{
        "valid" => false,
        "error" => "Invalid API key"
      } = json_response(conn, 401)
    end

    test "returns error response when key parameter is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/validate-key", %{})
      
      assert %{
        "valid" => false,
        "error" => "API key parameter is required"
      } = json_response(conn, 400)
    end
  end
end