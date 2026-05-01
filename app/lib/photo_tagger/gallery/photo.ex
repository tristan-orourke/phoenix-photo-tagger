defmodule PhotoTagger.Gallery.Photo do
  use Ecto.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Tag

  schema "photos" do
    field :name, :string
    field :image, PhotoTagger.Uploaders.ImageUploader.Type
    field :description, :string
    field :notes, :string
    field :image_last_modified, :utc_datetime
    field :group, :string
    field :is_public, :boolean, default: false
    field :manual_order, :integer

    timestamps(type: :utc_datetime)

    many_to_many :tags, Tag,
      join_through: "photos_tags",
      unique: true,
      preload_order: [asc: :name]

    belongs_to :folder, PhotoTagger.Gallery.Folder
    belongs_to :original_photo, __MODULE__, foreign_key: :original_photo_id
    has_many :cross_listings, __MODULE__, foreign_key: :original_photo_id
  end

  @doc false
  def changeset_create(photo, attrs) do
    photo
    |> cast(attrs, [
      :name,
      :folder_id,
      :description,
      :notes,
      :image_last_modified,
      :group,
      :is_public,
      :manual_order,
      :original_photo_id
    ])
    |> cast_attachments(attrs, [:image], allow_urls: true)
    |> validate_required([:name, :folder_id, :image, :image_last_modified])
    |> unique_constraint([:name, :folder_id])
    |> unique_constraint(:manual_order, name: :photos_manual_order_unique)
  end

  def changeset_update(photo, attrs) do
    photo
    |> cast(attrs, [
      :name,
      :image,
      :folder_id,
      :description,
      :notes,
      :group,
      :is_public,
      :manual_order
    ])
    |> unique_constraint([:name, :folder_id])
    |> unique_constraint(:manual_order, name: :photos_manual_order_unique)
  end
end
