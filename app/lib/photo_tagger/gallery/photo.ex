defmodule PhotoTagger.Gallery.Photo do
  use Ecto.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Tag

  schema "photos" do
    field :name, :string
    field :folder, :string
    field :image, PhotoTagger.Uploaders.ImageUploader.Type

    timestamps(type: :utc_datetime)
    many_to_many :tags, Tag, join_through: "photos_tags", unique: true, preload_order: [asc: :name]
  end

  # def changeset(photo, attrs = %{"add_tag" => tag}) do
  #   changeset(photo, Map.delete(attrs, "add_tag"))
  #     |>
  # end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:name, :folder])
    |> cast_attachments(attrs, [:image], allow_urls: true)
    |> validate_required([:name, :folder, :image])
    |> unique_constraint(:name)
  end

  # defp get_or_insert_tag(name) do
  #   Repo.insert!(
  #     %Tag{name: name},
  #     on_conflict: [set: [name: name]],
  #     conflict_target: :name
  #   )
  # end

  # defp insert_and_get_all_tags([]) do
  #   []
  # end
  # defp insert_and_get_all_tags(names) do
  #   timestamp =
  #     NaiveDateTime.utc_now()
  #     |> NaiveDateTime.truncate(:second)

  #   placeholders = %{timestamp: timestamp}

  #   maps =
  #     Enum.map(names, &%{
  #       name: &1,
  #       inserted_at: {:placeholder, :timestamp},
  #       updated_at: {:placeholder, :timestamp}
  #     })

  #   Repo.insert_all(
  #     Tag,
  #     maps,
  #     placeholders: placeholders,
  #     on_conflict: :nothing
  #   )

  #   Repo.all(from t in Tag, where: t.name in ^names)
  # end
end
