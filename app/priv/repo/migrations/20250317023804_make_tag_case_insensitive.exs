defmodule PhotoTagger.Repo.Migrations.MakeTagCaseInsensitive do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      modify :name, :citext
    end
  end
end
