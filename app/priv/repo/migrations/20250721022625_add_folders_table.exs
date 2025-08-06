defmodule PhotoTagger.Repo.Migrations.AddFoldersTable do
  use Ecto.Migration

  def change do
    create table(:folders) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:folders, [:name])
  end
end
