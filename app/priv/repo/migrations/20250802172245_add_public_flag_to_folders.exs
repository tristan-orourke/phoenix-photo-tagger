defmodule PhotoTagger.Repo.Migrations.AddPublicFlagToFolders do
  use Ecto.Migration

  def change do
    alter table(:folders) do
      add :is_public, :boolean, default: false, null: false
    end
  end
end
