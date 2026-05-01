defmodule PhotoTagger.Repo.Migrations.AddUniqueIndexOnManualOrder do
  use Ecto.Migration

  def up do
    execute """
    ALTER TABLE photos
    ADD CONSTRAINT photos_manual_order_unique UNIQUE (manual_order) DEFERRABLE INITIALLY DEFERRED
    """
  end

  def down do
    execute """
    ALTER TABLE photos
    DROP CONSTRAINT photos_manual_order_unique
    """
  end
end
