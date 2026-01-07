defmodule PhotoTagger.Repo.Migrations.AlterPhotosAddManualOrder do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add :manual_order, :integer
    end
  end
end
