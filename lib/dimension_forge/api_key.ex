defmodule DimensionForge.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_keys" do
    field(:active, :boolean, default: false)
    field(:name, :string)
    field(:key, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:key, :name, :active])
    |> validate_required([:key, :name, :active])
    |> unique_constraint(:key)
  end
end
