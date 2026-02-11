defmodule PhotoTagger.Repo.Migrations.AddOriginalPhotoIdToPhotos do
	use Ecto.Migration

	def change do
		alter table(:photos) do
			add :original_photo_id, references(:photos, on_delete: :delete_all), null: true
		end

		create index(:photos, [:original_photo_id])
	end
end
