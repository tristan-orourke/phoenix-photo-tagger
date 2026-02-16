defmodule PhotoTagger.Repo.Migrations.AddOriginalPhotoIdToPhotos do
  @moduledoc """
  Adds support for cross-listing photos across multiple folders.

  Cross-listings are database references to an original photo, allowing
  a single file to appear in multiple folders with independent metadata.
  """
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :original_photo_id, references(:photos, on_delete: :delete_all), null: true
    end

    create index(:photos, [:original_photo_id])
  end
end
