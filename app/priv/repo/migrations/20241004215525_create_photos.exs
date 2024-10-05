defmodule PhotoTagger.Repo.Migrations.CreatePhotos do
  use Ecto.Migration

  def change do
    create table(:photos) do
      add :name, :string
      add :folder, :string
      add :image, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:photos, [:name, :folder])

    # Create photos_tags pivot table
    create table(:photos_tags, primary_key: false) do
      add :photo_id, references(:photos, on_delete: :delete_all)
      add :tag_id, references(:tags, on_delete: :delete_all)
    end

    create unique_index(:photos_tags, [:photo_id, :tag_id])
  end
end
