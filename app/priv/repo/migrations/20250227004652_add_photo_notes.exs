defmodule PhotoTagger.Repo.Migrations.AddPhotoNotes do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :description, :text
      add :notes, :text
    end
  end
end
