defmodule PhotoTagger.Repo.Migrations.AddManualOrderToPhotos do
  use Ecto.Migration

  def up do
    alter table(:photos) do
      add :manual_order, :integer
    end

    create index(:photos, [:folder_id, :manual_order])

    # Initialize manual_order based on inserted_at within each folder
    execute """
    WITH ranked_photos AS (
      SELECT id, ROW_NUMBER() OVER (PARTITION BY folder_id ORDER BY inserted_at DESC, name ASC) as rn
      FROM photos
    )
    UPDATE photos
    SET manual_order = ranked_photos.rn
    FROM ranked_photos
    WHERE photos.id = ranked_photos.id
    """
  end

  def down do
    drop index(:photos, [:folder_id, :manual_order])

    alter table(:photos) do
      remove :manual_order
    end
  end
end
