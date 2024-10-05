defmodule PhotoTagger.Gallery.Photo do
  use Ecto.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset

  schema "photos" do
    field :name, :string
    field :folder, :string
    field :image, PhotoTagger.Uploaders.ImageUploader.Type

    timestamps(type: :utc_datetime)
    many_to_many :tags, PhotoTagger.Tag, join_through: "photos_tags", unique: true, preload_order: [asc: :name]
  end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:name, :folder])
    |> cast_attachments(attrs, [:image], allow_urls: true)
    |> validate_required([:name, :folder, :image])
    |> unique_constraint(:name)
  end
end
