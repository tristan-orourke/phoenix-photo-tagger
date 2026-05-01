defmodule PhotoTagger.Repo.Migrations.AddUniqueConstraintOnManualOrder do
  use Ecto.Migration

  def up do
    # Assign manual_order to any photos that currently have NULL
    execute """
    UPDATE photos
    SET manual_order = subquery.new_order
    FROM (
      SELECT id,
             (SELECT COALESCE(MAX(manual_order), 0) FROM photos) +
             ROW_NUMBER() OVER (ORDER BY inserted_at DESC, name ASC) AS new_order
      FROM photos
      WHERE manual_order IS NULL
    ) AS subquery
    WHERE photos.id = subquery.id
    """

    execute """
    ALTER TABLE photos
    ALTER COLUMN manual_order SET NOT NULL
    """

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

    execute """
    ALTER TABLE photos
    ALTER COLUMN manual_order DROP NOT NULL
    """
  end
end
