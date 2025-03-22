defmodule PhotoTagger.Repo.Migrations.AddPhotoImageLastModified do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :image_last_modified, :utc_datetime
    end
  end
end
