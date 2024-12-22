defmodule PhotoTagger.Gallery.PhotoTag do
  use Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Gallery.Tag

  @primary_key false
  schema "photos_tags" do
    belongs_to :photo, Photo, primary_key: true
    belongs_to :tag, Tag, primary_key: true
  end

  @required_fields [:photo_id, :tag_id]
  def changeset(photo_tag, params \\ %{}) do
    photo_tag
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:photo_id)
    |> foreign_key_constraint(:tag_id)
    |> unique_constraint([:photo, :tag])
  end
end
