defmodule PhotoTagger.Repo.Migrations.AddPublicFlagToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :is_public, :boolean, default: false, null: false
    end
  end
end
