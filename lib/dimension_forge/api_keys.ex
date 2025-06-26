defmodule DimensionForge.ApiKeys do
  @moduledoc """
  The ApiKeys context.
  """

  import Ecto.Query, warn: false
  alias DimensionForge.Repo
  alias DimensionForge.ApiKey

  @doc """
  Creates an API key with a generated key string.

  ## Examples

      iex> create_api_key(%{name: "Test API"})
      {:ok, %ApiKey{}}

      iex> create_api_key(%{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_api_key(attrs \\ %{}) do
    attrs_with_key = Map.put(attrs, "key", generate_api_key())
    attrs_with_active = Map.put(attrs_with_key, "active", true)

    %ApiKey{}
    |> ApiKey.changeset(attrs_with_active)
    |> Repo.insert()
  end

  @doc """
  Validates if an API key exists and is active.

  ## Examples

      iex> validate_api_key("valid_key")
      {:ok, %ApiKey{}}

      iex> validate_api_key("invalid_key")
      {:error, :invalid_key}

  """
  def validate_api_key(key) when is_binary(key) do
    case Repo.get_by(ApiKey, key: key, active: true) do
      %ApiKey{} = api_key -> {:ok, api_key}
      nil -> {:error, :invalid_key}
    end
  end

  @doc """
  Deletes an API key.

  ## Examples

      iex> delete_api_key(api_key)
      {:ok, %ApiKey{}}

      iex> delete_api_key(api_key)
      {:error, %Ecto.Changeset{}}

  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  @doc """
  Gets a single API key by key string.

  ## Examples

      iex> get_api_key_by_key("some_key")
      %ApiKey{}

      iex> get_api_key_by_key("invalid_key")
      nil

  """
  def get_api_key_by_key(key) when is_binary(key) do
    Repo.get_by(ApiKey, key: key)
  end

  @doc """
  Lists all API keys.

  ## Examples

      iex> list_api_keys()
      [%ApiKey{}, ...]

  """
  def list_api_keys do
    Repo.all(ApiKey)
  end

  defp generate_api_key do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
    |> binary_part(0, 32)
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> String.pad_trailing(32, "0")
  end
end
