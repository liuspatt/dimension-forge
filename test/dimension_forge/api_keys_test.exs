defmodule DimensionForge.ApiKeysTest do
  use DimensionForge.DataCase

  alias DimensionForge.ApiKeys
  alias DimensionForge.ApiKey

  describe "create_api_key/1" do
    test "creates an API key with valid attributes" do
      attrs = %{"name" => "Test API Key"}

      assert {:ok, %ApiKey{} = api_key} = ApiKeys.create_api_key(attrs)
      assert api_key.name == "Test API Key"
      assert api_key.active == true
      assert String.length(api_key.key) == 32
      assert api_key.key =~ ~r/^[A-Za-z0-9]+$/
    end

    test "returns error changeset with invalid attributes" do
      attrs = %{"name" => ""}

      assert {:error, %Ecto.Changeset{}} = ApiKeys.create_api_key(attrs)
    end

    test "generates unique keys for multiple API keys" do
      attrs1 = %{"name" => "Test API Key 1"}
      attrs2 = %{"name" => "Test API Key 2"}

      {:ok, api_key1} = ApiKeys.create_api_key(attrs1)
      {:ok, api_key2} = ApiKeys.create_api_key(attrs2)

      assert api_key1.key != api_key2.key
    end
  end

  describe "validate_api_key/1" do
    test "returns {:ok, api_key} for valid active key" do
      {:ok, api_key} = ApiKeys.create_api_key(%{"name" => "Test API"})

      assert {:ok, returned_api_key} = ApiKeys.validate_api_key(api_key.key)
      assert returned_api_key.id == api_key.id
    end

    test "returns {:error, :invalid_key} for non-existent key" do
      assert {:error, :invalid_key} = ApiKeys.validate_api_key("non_existent_key")
    end

    test "returns {:error, :invalid_key} for inactive key" do
      {:ok, api_key} = ApiKeys.create_api_key(%{"name" => "Test API"})

      # Manually set key as inactive
      api_key
      |> ApiKey.changeset(%{"active" => false})
      |> Repo.update!()

      assert {:error, :invalid_key} = ApiKeys.validate_api_key(api_key.key)
    end
  end

  describe "delete_api_key/1" do
    test "deletes the api_key" do
      {:ok, api_key} = ApiKeys.create_api_key(%{"name" => "Test API"})

      assert {:ok, %ApiKey{}} = ApiKeys.delete_api_key(api_key)
      assert_raise Ecto.NoResultsError, fn -> Repo.get!(ApiKey, api_key.id) end
    end
  end

  describe "get_api_key_by_key/1" do
    test "returns api_key when key exists" do
      {:ok, api_key} = ApiKeys.create_api_key(%{"name" => "Test API"})

      returned_api_key = ApiKeys.get_api_key_by_key(api_key.key)
      assert returned_api_key.id == api_key.id
    end

    test "returns nil when key doesn't exist" do
      assert ApiKeys.get_api_key_by_key("non_existent_key") == nil
    end
  end

  describe "list_api_keys/0" do
    test "returns all api_keys" do
      {:ok, api_key1} = ApiKeys.create_api_key(%{"name" => "Test API 1"})
      {:ok, api_key2} = ApiKeys.create_api_key(%{"name" => "Test API 2"})

      api_keys = ApiKeys.list_api_keys()

      assert length(api_keys) == 2
      api_key_ids = Enum.map(api_keys, & &1.id)
      assert api_key1.id in api_key_ids
      assert api_key2.id in api_key_ids
    end
  end
end
