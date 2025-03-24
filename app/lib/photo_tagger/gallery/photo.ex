defmodule PhotoTagger.Gallery.Photo do
  use Ecto.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Tag

  schema "photos" do
    field :name, :string
    field :folder, :string
    field :image, PhotoTagger.Uploaders.ImageUploader.Type
    field :description, :string
    field :notes, :string
    field :image_last_modified, :utc_datetime

    timestamps(type: :utc_datetime)

    many_to_many :tags, Tag,
      join_through: "photos_tags",
      unique: true,
      preload_order: [asc: :name]
  end

  @doc false
  def changeset_create(photo, attrs) do
    photo
    |> cast(attrs, [:name, :folder, :description, :notes, :image_last_modified])
    |> cast_attachments(attrs, [:image], allow_urls: true)
    |> validate_required([:name, :folder, :image, :image_last_modified])
    |> unique_constraint([:name, :folder])
  end

  def changeset_update(photo, attrs) do
    photo
    |> cast(attrs, [:name, :image, :folder, :description, :notes])
    |> unique_constraint([:name, :folder])
  end
end
