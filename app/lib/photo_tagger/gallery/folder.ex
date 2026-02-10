defmodule PhotoTagger.Gallery.Folder do
  @moduledoc """
  Represents a folder in the gallery.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PhotoTagger.Gallery.Photo

  @visibility_types ~w(private public unlisted)a

  schema "folders" do
    field :name, :string
    field :visibility_type, Ecto.Enum, values: @visibility_types

    timestamps(type: :utc_datetime)

    has_many :photos, Photo,
      #      foreign_key: :folder_id,
      on_delete: :delete_all
  end

  @doc false
  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:name, :visibility_type])
    |> validate_required([:name])
    |> validate_inclusion(:visibility_type, @visibility_types)
    |> unique_constraint(:name)
  end

  @doc """
  Returns the list of valid visibility types.
  """
  def visibility_types, do: @visibility_types
end
