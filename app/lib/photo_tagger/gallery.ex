defmodule PhotoTagger.Gallery do
  @moduledoc """
  The Gallery context.
  """

  import Ecto.Query, warn: false
  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Gallery.Tag
  alias PhotoTagger.Gallery.PhotoTag
  alias PhotoTagger.Uploaders.ImageUploader
  require Logger

  @doc """
  Returns the list of photos.

  ## Examples

      iex> list_photos()
      [%Photo{}, ...]

  """
  def list_photos do
    Repo.all(Photo)
  end

  def list_photos_by_folder(folder) do
    Repo.all(from(p in Photo, where: p.folder == ^folder))
  end

  defp photos_ids_by_tags([]) do
    Repo.all(from(p in Photo, select: p.id))
  end

  defp photos_ids_by_tags(tag_names) do
    tags = Repo.all(from(t in Tag, where: t.name in ^tag_names))

    case tags do
      [] ->
        []

      tags ->
        photo_ids =
          from(p in Photo,
            join: pt in PhotoTag,
            on: pt.photo_id == p.id,
            where: pt.tag_id in ^Enum.map(tags, & &1.id),
            group_by: p.id,
            having: count(pt.tag_id) == ^length(tag_names),
            select: p.id
          )
          |> Repo.all()

        photo_ids
    end
  end

  # Returns all photos that have ALL the specified tags
  def list_photos_by_all_tags([]), do: list_photos()

  def list_photos_by_all_tags(tag_names) do
    photo_ids = photos_ids_by_tags(tag_names)
    Repo.all(from(p in Photo, where: p.id in ^photo_ids))
  end

  def list_photos_by_folder_and_tags(folder, tag_names) do
    photo_ids = photos_ids_by_tags(tag_names)
    Repo.all(from(p in Photo, where: p.id in ^photo_ids, where: p.folder == ^folder))
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
    |> Photo.changeset_create(attrs)
    |> Repo.insert()
  end

  defp photo_full_path(%Photo{} = photo, version \\ :original) do
    # TODO if the image_uploader transform function changes, it might not be .jpg
    ext = if(version == :original, do: Path.extname(photo.image.file_name), else: ".jpg")
    Path.join([
      get_folder_path(photo.folder),
      ImageUploader.filename(version, {photo.image, photo}) <> ext
    ])
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

    # If the name is being updated, update the image file_name as well
    attrs = if(Map.has_key?(attrs, "name"), do:
      Map.put(attrs, "image", Map.replace(photo.image, :file_name, attrs["name"])),
      else: attrs)
    changeset = Photo.changeset_update(photo, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:photo, changeset)
    |> Ecto.Multi.run(:update_file, fn _repo, changes ->
      Enum.map(ImageUploader.versions(), fn version ->
        old_path = photo_full_path(photo, version)
        new_path = photo_full_path(changes.photo, version)
        {old_path, new_path}
      end)
      |> Enum.filter(fn {old_path, new_path} -> old_path != new_path end)
      # TODO: Before trying to move files, check that they all exist
      |> Enum.reduce({:ok, changes}, fn
        _paths, {:error, changes} -> {:error, changes} # Stop processing if there was an error
        {old_path, new_path}, {:ok, changes} ->
          case File.rename(old_path, new_path) do
            :ok -> {:ok, changes}
            {:error, reason} -> {:error, reason}
          end
      end)
    end)
    |> Repo.transaction()
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
    ImageUploader.delete({photo.image, photo})
    Repo.delete(photo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking photo changes.

  ## Examples

      iex> new_photo_changeset(photo)
      %Ecto.Changeset{data: %Photo{}}

  """
  def new_photo_changeset(%Photo{} = photo, attrs \\ %{}) do
    Photo.changeset_create(photo, attrs)
  end

  def update_photo_changeset(%Photo{} = photo, attrs \\ %{}) do
    Photo.changeset_update(photo, attrs)
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
        {:ok,
         Repo.get_by!(PhotoTag, photo_id: photo.id, tag_id: tag.id)
         |> Repo.delete!()}
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

  def list_folders() do
    Repo.all(from(p in Photo, group_by: p.folder, select: p.folder))
  end

  def list_folders_include_tags() do
    Repo.all(
      from(p in Photo,
        left_join: pt in PhotoTag,
        on: pt.photo_id == p.id,
        left_join: t in Tag,
        on: pt.tag_id == t.id,
        group_by: p.folder,
        select: %{
          name: p.folder,
          tags: fragment("array_agg(DISTINCT ?)", t.name)
        }
      )
    )
    # Filter out any tags that are nil or empty strings
    |> Enum.map(fn folder ->
      %{folder | tags: Enum.filter(folder.tags, fn tag -> tag != nil && tag != "" end)}
    end)
  end

  def list_tags() do
    Repo.all(from t in Tag, order_by: [asc: t.name])
  end

  defp get_folder_path(folder) do
    Path.join([Application.get_env(:waffle, :storage_dir_prefix), ImageUploader.storage_dir(nil, {nil, %{folder: folder}})])
  end

  def rename_folder(folder, new_folder) do
    Ecto.Multi.new()
    |> Ecto.Multi.update_all(:photos, from(p in Photo, where: p.folder == ^folder), set: [folder: new_folder])
    |> Ecto.Multi.run(:rename_folder, fn _repo, _changes ->
        old_path = get_folder_path(folder)
        new_path = get_folder_path(new_folder)

        case File.rename(old_path, new_path) do
          :ok -> {:ok, new_path}
          {:error, reason} -> {:error, reason}
        end
      end)
    |> Repo.transaction()
  end

  def delete_folder(folder) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:photos, from(p in Photo, where: p.folder == ^folder))
    |> Ecto.Multi.delete_all(:tags, from(t in Tag, where: fragment("? NOT IN (SELECT tag_id FROM photos_tags)", t.id)))
    |> Ecto.Multi.run(:delete_folder, fn _repo, _changes ->
        File.rm_rf(get_folder_path(folder))
      end)
    |> Repo.transaction()
  end
end
