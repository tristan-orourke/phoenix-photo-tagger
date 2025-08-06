defmodule PhotoTagger.Gallery.Folder do
  @moduledoc """
  Represents a folder in the gallery.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Photo

  schema "folders" do
    field :name, :string
    field :is_public, :boolean

    timestamps(type: :utc_datetime)

    has_many :photos, Photo,
      #      foreign_key: :folder_id,
      on_delete: :delete_all
  end

  @doc false
  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:name, :is_public])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
