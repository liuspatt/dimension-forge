defmodule DimensionForge.Images do
  @moduledoc """
  Context for managing images
  """

  import Ecto.Query, warn: false
  alias DimensionForge.Repo
  alias DimensionForge.Images.Image

  @doc """
  Creates an image record
  """
  def create_image(attrs \\ %{}) do
    %Image{}
    |> Image.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an image by project name and image ID
  """
  def get_image(project_name, image_id) do
    Repo.get_by(Image, project_name: project_name, image_id: image_id)
  end

  @doc """
  Gets an image by ID
  """
  def get_image!(id) do
    Repo.get!(Image, id)
  end

  @doc """
  Lists images for a project
  """
  def list_images(project_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    from(i in Image,
      where: i.project_name == ^project_name,
      order_by: [desc: i.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Adds a variant to an existing image
  """
  def add_variant(%Image{} = image, variant_key, url) do
    new_variants = Map.put(image.variants, variant_key, url)

    image
    |> Image.changeset(%{variants: new_variants})
    |> Repo.update()
  end

  @doc """
  Deletes an image
  """
  def delete_image(%Image{} = image) do
    Repo.delete(image)
  end

  @doc """
  Updates an image
  """
  def update_image(%Image{} = image, attrs) do
    image
    |> Image.changeset(attrs)
    |> Repo.update()
  end
end
