defmodule PhotoTagger.Repo.Migrations.AddFoldersForeignKeyToPhotos do
  use Ecto.Migration

  def up do
    alter table(:photos) do
      add :folder_id, references(:folders, on_delete: :delete_all)
    end

    # Populate the folders table
    execute("""
    INSERT INTO folders (name, inserted_at, updated_at)
    SELECT DISTINCT folder, NOW(), NOW()
    FROM photos
    WHERE folder IS NOT NULL
      AND folder NOT IN (SELECT name FROM folders);
    """)

    # Ensure that all existing photos have a folder_id set to the default folder (if it exists)
    execute("""
    UPDATE photos
    SET folder_id = (
      SELECT id FROM folders WHERE folders.name = photos.folder
    )
    WHERE folder_id IS NULL;
    """)

    # We must drop the constraint, as it will be re-added when we modify the foreign key
    drop constraint(:photos, :photos_folder_id_fkey)

    # Now we can modify the foreign key to be non-nullable
    alter table(:photos) do
      modify :folder_id, references(:folders, on_delete: :delete_all), null: false
    end

    # Finally, we can add the unique index on name and folder_id
    create unique_index(:photos, [:name, :folder_id])
  end

  def down do
    alter table(:photos) do
      remove :folder_id
    end
  end
end
