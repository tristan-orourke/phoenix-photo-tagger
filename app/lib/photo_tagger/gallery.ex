defmodule PhotoTagger.Gallery do
  @moduledoc """
  The Gallery context.
  """

  import Ecto.Query, warn: false
  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Gallery.Tag
  alias PhotoTagger.Gallery.PhotoTag

  @doc """
  Returns the list of photos.

  ## Examples

      iex> list_photos()
      [%Photo{}, ...]

  """
  def list_photos do
    Repo.all(Photo)
  end

  # Returns all photos that have ALL the specified tags
  def list_photos_by_all_tags([]), do: list_photos()
  def list_photos_by_all_tags(tag_names) do
    tags = Repo.all(from(t in Tag, where: t.name in ^tag_names))

    case tags do
      [] ->
        []

      tags ->
        photo_ids =
          from(p in Photo,
            join: pt in "photos_tags",
            on: pt.photo_id == p.id,
            where: pt.tag_id in ^Enum.map(tags, & &1.id),
            group_by: p.id,
            having: count(pt.tag_id) == ^length(tag_names),
            select: p.id
          )
          |> Repo.all()

        Repo.all(from(p in Photo, where: p.id in ^photo_ids))
    end
  end

  @doc """
  Gets a single photo.

  Raises `Ecto.NoResultsError` if the Photo does not exist.

  ## Examples

      iex> get_photo!(123)
      %Photo{}

      iex> get_photo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_photo!(id) do
    Repo.get!(Photo, id)
    # Repo.preload(photo, :tags)
  end

  @doc """
  Creates a photo.

  ## Examples

      iex> create_photo(%{field: value})
      {:ok, %Photo{}}

      iex> create_photo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_photo(attrs \\ %{}) do
    attrs = Map.put(attrs, "name", attrs["image"].filename)

    %Photo{}
    |> Photo.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a photo.

  ## Examples

      iex> update_photo(photo, %{field: new_value})
      {:ok, %Photo{}}

      iex> update_photo(photo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_photo(%Photo{} = photo, attrs) do
    photo
    |> Photo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a photo.

  ## Examples

      iex> delete_photo(photo)
      {:ok, %Photo{}}

      iex> delete_photo(photo)
      {:error, %Ecto.Changeset{}}

  """
  def delete_photo(%Photo{} = photo) do
    Repo.delete(photo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking photo changes.

  ## Examples

      iex> change_photo(photo)
      %Ecto.Changeset{data: %Photo{}}

  """
  def change_photo(%Photo{} = photo, attrs \\ %{}) do
    Photo.changeset(photo, attrs)
  end

  def add_tag_to_photo(%Photo{} = photo, name) do
    tag = get_or_create_tag(name)
    attrs = %{photo_id: photo.id, tag_id: tag.id}

    %PhotoTag{}
    |> PhotoTag.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  def remove_tag_from_photo(%Photo{} = photo, name) do
    tag = Repo.get_by(Ecto.assoc(photo, :tags), name: name)

    case tag do
      nil ->
        {:ok, nil}

      tag ->
        Repo.get_by!(PhotoTag, photo_id: photo.id, tag_id: tag.id)
        |> Repo.delete!()
    end
  end

  defp get_or_create_tag(name) do
    Repo.get_by(Tag, name: name) ||
      maybe_insert_tag(name)
  end

  defp maybe_insert_tag(name) do
    %Tag{}
    |> Tag.changeset(%{name: name})
    |> Repo.insert()
    |> case do
      {:ok, tag} -> tag
      {:error, _} -> Repo.get_by!(Tag, name: name)
    end
  end
end
