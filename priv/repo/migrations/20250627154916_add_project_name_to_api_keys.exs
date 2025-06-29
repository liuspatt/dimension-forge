defmodule DimensionForge.Repo.Migrations.AddProjectNameToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :project_name, :string, null: true
    end

    execute "UPDATE api_keys SET project_name = 'default' WHERE project_name IS NULL"

    alter table(:api_keys) do
      modify :project_name, :string, null: false
    end

    create index(:api_keys, [:project_name])
  end
end
