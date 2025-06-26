defmodule DimensionForge.Images.Image do
  @moduledoc """
  Image schema
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  schema "images" do
    field :project_name, :string
    field :image_name, :string
    field :image_id, :string
    field :original_filename, :string
    field :original_url, :string
    field :content_type, :string
    field :file_size, :integer
    field :width, :integer
    field :height, :integer
    field :formats, {:array, :string}
    field :variants, :map
    field :public, :boolean, default: true
    field :api_key_id, :integer
    
    timestamps()
  end
  
  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [
      :project_name, :image_name, :image_id, :original_filename,
      :original_url, :content_type, :file_size, :width, :height,
      :formats, :variants, :public, :api_key_id
    ])
    |> validate_required([
      :project_name, :image_name, :image_id, :original_filename,
      :original_url, :content_type, :file_size
    ])
    |> validate_length(:project_name, min: 1, max: 100)
    |> validate_length(:image_name, min: 1, max: 255)
    |> validate_length(:image_id, min: 1, max: 100)
    |> validate_number(:file_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> unique_constraint([:project_name, :image_id])
  end
end