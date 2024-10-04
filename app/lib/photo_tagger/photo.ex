defmodule PhotoTagger.Photo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "photos" do
    field :name, :string

    timestamps(type: :utc_datetime)
    many_to_many :tags, PhotoTagger.Tag, join_through: "photos_tags", unique: true, preload_order: [asc: :name]
  end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
