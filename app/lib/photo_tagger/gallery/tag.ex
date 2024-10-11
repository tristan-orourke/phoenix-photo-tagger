defmodule PhotoTagger.Gallery.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Photo

  schema "tags" do
    field :name, :string

    timestamps(type: :utc_datetime)

    many_to_many :photos, Photo,
      join_through: "photos_tags",
      unique: true,
      preload_order: [asc: :name]
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
