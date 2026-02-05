defmodule PhotoTagger.Repo.Migrations.AddVisibilityTypeToFolders do
  use Ecto.Migration

  def up do
    # Create the enum type
    execute """
    CREATE TYPE folder_visibility_type AS ENUM ('private', 'public', 'unlisted')
    """

    # Add the new column with default
    alter table(:folders) do
      add :visibility_type, :folder_visibility_type, default: "private", null: false
    end

    # Migrate existing data: is_public = true -> public, is_public = false -> private
    execute """
    UPDATE folders
    SET visibility_type = CASE
      WHEN is_public = true THEN 'public'::folder_visibility_type
      ELSE 'private'::folder_visibility_type
    END
    """

    # Drop the old column
    alter table(:folders) do
      remove :is_public
    end
  end

  def down do
    # Add back the is_public column
    alter table(:folders) do
      add :is_public, :boolean, default: false, null: false
    end

    # Migrate data back: public/unlisted -> true, private -> false
    # Note: unlisted will be converted to public on rollback
    execute """
    UPDATE folders
    SET is_public = CASE
      WHEN visibility_type IN ('public', 'unlisted') THEN true
      ELSE false
    END
    """

    # Remove the visibility_type column
    alter table(:folders) do
      remove :visibility_type
    end

    # Drop the enum type
    execute "DROP TYPE folder_visibility_type"
  end
end
