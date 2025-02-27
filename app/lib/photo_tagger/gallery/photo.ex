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

    timestamps(type: :utc_datetime)
    many_to_many :tags, Tag, join_through: "photos_tags", unique: true, preload_order: [asc: :name]
  end

  # def changeset(photo, attrs = %{"add_tag" => tag}) do
  #   changeset(photo, Map.delete(attrs, "add_tag"))
  #     |>
  # end

  @doc false
  def changeset_create(photo, attrs) do
    photo
    |> cast(attrs, [:name, :folder, :description, :notes])
    |> cast_attachments(attrs, [:image], allow_urls: true)
    |> validate_required([:name, :folder, :image])
    |> unique_constraint([:name, :folder])
  end

  def changeset_update(photo, attrs) do
    photo
    |> cast(attrs, [:name, :image, :folder, :description, :notes])
    |> unique_constraint([:name, :folder])
  end
end
