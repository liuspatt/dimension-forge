defmodule DimensionForge.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :project_name, :string, null: false
      add :image_name, :string, null: false
      add :image_id, :string, null: false
      add :original_filename, :string, null: false
      add :original_url, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :width, :integer
      add :height, :integer
      add :formats, {:array, :string}, default: []
      add :variants, :map, default: %{}
      add :public, :boolean, default: true
      add :api_key_id, :integer
      
      timestamps()
    end

    create unique_index(:images, [:project_name, :image_id])
    create index(:images, [:project_name])
    create index(:images, [:api_key_id])
  end
end
