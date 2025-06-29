defmodule DimensionForge.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_keys" do
    field(:active, :boolean, default: false)
    field(:name, :string)
    field(:key, :string)
    field(:project_name, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:key, :name, :active, :project_name])
    |> validate_required([:key, :name, :active, :project_name])
    |> validate_length(:project_name, min: 1, max: 100)
    |> unique_constraint(:key)
  end
end
