defmodule PhotoTagger.Repo.Migrations.AddGroupFieldToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :group, :string
    end
  end
end
