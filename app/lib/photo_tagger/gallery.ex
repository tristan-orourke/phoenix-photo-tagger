defmodule PhotoTagger.Gallery do
  @moduledoc """
  The Gallery context.
  """

  import Ecto.Query, warn: false
  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery.Photo
  alias PhotoTagger.Gallery.Tag
  alias PhotoTagger.Gallery.PhotoTag
  alias PhotoTagger.Gallery.Folder
  alias PhotoTagger.Uploaders.ImageUploader

  defp only_public_photos(query) do
    case Ecto.Query.has_named_binding?(query, :folder) do
      true ->
        from([folder: f] in query,
          where: f.is_public == true
        )

      false ->
        from(p in query,
          left_join: f in assoc(p, :folder),
          as: :folder,
          where: f.is_public == true
        )
    end
  end

  defp only_public_photos_unless_forced(query, options \\ []) do
    if Keyword.get(options, :include_private, false) do
      query
    else
      only_public_photos(query)
    end
  end

  defp only_public_folders_unless_forced(query, options) do
    if Keyword.get(options, :include_private, false) do
      query
    else
      from(f in query, where: f.is_public == true)
    end
  end

  @doc """
  Returns the list of photos.

  ## Examples

      iex> list_photos()
      [%Photo{}, ...]

  """
  def list_photos(options \\ []) do
    Repo.all(
      from(p in Photo,
        preload: [:folder],
        order_by: [desc: p.inserted_at],
        order_by: [asc: p.name]
      )
      |> only_public_photos_unless_forced(options)
    )
  end

  def list_photos_preload_tags(options \\ []) do
    Repo.all(
      from(p in Photo,
        left_join: t in assoc(p, :tags),
        preload: [tags: t],
        preload: [:folder],
        order_by: [desc: p.inserted_at],
        order_by: [asc: p.name],
        select: p
      )
      |> only_public_photos_unless_forced(options)
    )
  end

  def list_photos_by_folder(folder_name, options \\ []) do
    Repo.all(
      from(p in Photo,
        inner_join: f in assoc(p, :folder),
        as: :folder,
        where: f.name == ^folder_name,
        preload: [folder: f],
        order_by: [desc: p.inserted_at],
        order_by: [asc: p.name]
      )
      |> only_public_photos_unless_forced(options)
    )
  end

  def list_photos_by_folder_preload_tags(folder_name, options \\ []) do
    Repo.all(
      from(p in Photo,
        left_join: t in assoc(p, :tags),
        inner_join: f in assoc(p, :folder),
        as: :folder,
        where: f.name == ^folder_name,
        preload: [tags: t],
        preload: [folder: f],
        order_by: [desc: p.inserted_at],
        order_by: [asc: p.name]
      )
      |> only_public_photos_unless_forced(options)
    )
  end

  # If tag_names is nil, return all photos that have no tags
  defp photos_by_tags_query(nil) do
    from(p in Photo,
      as: :photo,
      where: not exists(from(pt in PhotoTag, where: pt.photo_id == parent_as(:photo).id)),
      select: p
    )
  end

  defp photos_by_tags_query([]) do
    from(p in Photo, select: p)
  end

  defp photos_by_tags_query(tag_names) do
    case tag_names do
      [] ->
        []

      _ ->
        from(p in Photo,
          inner_join:
            sub in subquery(
              from(p in Photo,
                inner_join: pt in PhotoTag,
                on: pt.photo_id == p.id,
                inner_join: t in Tag,
                on: pt.tag_id == t.id,
                where: t.name in ^tag_names,
                group_by: p.id,
                select: %{photo_id: p.id, tag_count: count(pt.tag_id)}
              )
            ),
          on: sub.photo_id == p.id,
          where: sub.tag_count == ^length(tag_names),
          order_by: [desc: p.inserted_at],
          order_by: [asc: p.name],
          select: p
        )
    end
  end

  # Returns all photos that have ALL the specified tags
  def list_photos_by_all_tags(tag_names, options \\ [])
  def list_photos_by_all_tags([], options), do: list_photos(options)

  def list_photos_by_all_tags(tag_names, options) do
    query = photos_by_tags_query(tag_names)

    Repo.all(
      from(p in query,
        preload: [:folder],
        order_by: [desc: p.inserted_at],
        order_by: [asc: p.name]
      )
      |> only_public_photos_unless_forced(options)
    )
  end

  def list_photos_by_folder_and_tags(folder_name, tag_names, options \\ []) do
    query = photos_by_tags_query(tag_names)

    Repo.all(
      from(p in query,
        join: f in assoc(p, :folder),
        as: :folder,
        where: f.name == ^folder_name,
        preload: [folder: f]
      )
      |> only_public_photos_unless_forced(options)
    )
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

  def get_photos_by_ids(ids) do
    Repo.all(from(p in Photo, where: p.id in ^ids))
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

  defp photo_full_path(%Photo{} = photo, version) do
    # TODO if the image_uploader transform function changes, it might not be .jpg
    ext = if(version == :original, do: Path.extname(photo.image.file_name), else: ".jpg")
    photo = Repo.preload(photo, :folder)

    Path.join([
      get_folder_path(photo.folder.name),
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
    attrs =
      if(Map.has_key?(attrs, "name"),
        do: Map.put(attrs, "image", Map.replace(photo.image, :file_name, attrs["name"])),
        else: attrs
      )

    changeset = Photo.changeset_update(photo, attrs)

    Repo.preload(photo, :folder)

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
        # Stop processing if there was an error
        _paths, {:error, changes} ->
          {:error, changes}

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

  def get_tag_by_name!(name) do
    Repo.get_by!(Tag, name: name)
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

  def list_folders(options \\ []) do
    Repo.all(
      from(f in Folder, order_by: [asc: f.name])
      |> only_public_folders_unless_forced(options)
    )
  end

  def list_folders_include_tags(options \\ []) do
    Repo.all(
      from(
        f in Folder,
        left_join: p in Photo,
        on: p.folder_id == f.id,
        inner_join: pt in PhotoTag,
        on: pt.photo_id == p.id,
        inner_join: t in Tag,
        on: pt.tag_id == t.id,
        group_by: f.id,
        select: %{
          name: f.name,
          tags: fragment("array_agg(DISTINCT ?)", t.name)
        }
      )
      |> only_public_folders_unless_forced(options)
    )
    # Filter out any tags that are nil or empty strings
    |> Enum.map(fn folder ->
      %{folder | tags: Enum.filter(folder.tags, fn tag -> tag != nil && tag != "" end)}
    end)
  end

  # TODO: be more careful about this when individual photos can be private
  def list_tags() do
    Repo.all(from t in Tag, order_by: [asc: t.name])
  end

  # TODO: be more careful about this when individual photos can be private
  def list_tags_by_folder(folder_name) do
    Repo.all(
      from(t in Tag,
        left_join: pt in PhotoTag,
        on: pt.tag_id == t.id,
        left_join: p in Photo,
        on: pt.photo_id == p.id,
        left_join: f in assoc(p, :folder),
        on: pt.photo_id == p.id,
        where: f.name == ^folder_name,
        group_by: t.id,
        order_by: [asc: t.name]
      )
    )
  end

  # Get all the tags which are associated with the at least one of the given photos
  def list_tags_by_photos(photo_ids) do
    Repo.all(
      from t in Tag,
        left_join: pt in PhotoTag,
        on: pt.tag_id == t.id,
        where: pt.photo_id in ^photo_ids,
        order_by: [asc: t.name],
        distinct: true,
        select: t
    )
  end

  defp get_folder_path(folder_name) do
    Path.join([
      Application.get_env(:waffle, :storage_dir_prefix),
      ImageUploader.storage_dir(nil, {nil, %{folder: %{name: folder_name}}})
    ])
  end

  def get_folder_by_name!(name) do
    Repo.get_by!(Folder, name: name)
  end

  def create_folder(%{"name" => name, "is_public" => _is_public} = attrs) do
    changeset = %Folder{} |> Folder.changeset(attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:create_folder_db, changeset)
    |> Ecto.Multi.run(:create_folder_path, fn _repo, _changes ->
      path = get_folder_path(name)

      case File.mkdir(path) do
        :ok -> {:ok, path}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Repo.transaction()
  end

  def update_folder(%Folder{} = folder, attrs) do
    changeset = Folder.changeset(folder, attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:update_folder_db, changeset)
    |> Ecto.Multi.run(:update_folder_path, fn _repo, _changes ->
      old_path = get_folder_path(folder.name)
      new_path = get_folder_path(attrs["name"])

      if old_path == new_path do
        {:ok, old_path}
      else
        case File.rename(old_path, new_path) do
          :ok -> {:ok, new_path}
          {:error, reason} -> {:error, reason}
        end
      end
    end)
    |> Repo.transaction()
  end

  def rename_folder(folder_name, new_folder_name) do
    changeset =
      Repo.get_by(Folder, name: folder_name)
      |> Folder.changeset(%{name: new_folder_name})

    Ecto.Multi.new()
    |> Ecto.Multi.update(:rename_folder_db, changeset)
    |> Ecto.Multi.run(:rename_folder_path, fn _repo, _changes ->
      old_path = get_folder_path(folder_name)
      new_path = get_folder_path(new_folder_name)

      case File.rename(old_path, new_path) do
        :ok -> {:ok, new_path}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Repo.transaction()
  end

  def delete_folder(folder_name) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(
      :photos,
      from(p in Photo, inner_join: f in assoc(p, :folder), where: f.name == ^folder_name)
    )
    |> Ecto.Multi.delete_all(
      :tags,
      from(t in Tag, where: fragment("? NOT IN (SELECT tag_id FROM photos_tags)", t.id))
    )
    |> Ecto.Multi.delete(:folders, Repo.get_by(Folder, name: folder_name))
    |> Ecto.Multi.run(:delete_folder, fn _repo, _changes ->
      File.rm_rf(get_folder_path(folder_name))
    end)
    |> Repo.transaction()
  end

  def update_tag(%Tag{} = tag, attrs) do
    Tag.changeset(tag, attrs)
    |> Repo.update()
  end

  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  def delete_orphan_tags() do
    Repo.delete_all(
      from(t in Tag,
        where: fragment("? NOT IN (SELECT tag_id FROM photos_tags)", t.id)
      )
    )
  end

  # Get all photos with at least one overlapping tag with photo.
  # Return all tags from those photos, not including tags from the original photo.
  def get_related_tags(%Photo{} = photo) do
    # Get all tags from the original photo
    original_tag_ids =
      Repo.all(
        from(t in Tag,
          join: pt in PhotoTag,
          on: pt.tag_id == t.id,
          where: pt.photo_id == ^photo.id,
          select: t.id
        )
      )

    # Get all photos with at least one overlapping tag with the original photo
    related_photos =
      Repo.all(
        from(p in Photo,
          join: pt in PhotoTag,
          on: pt.photo_id == p.id,
          where: pt.tag_id in ^original_tag_ids and p.id != ^photo.id,
          select: p.id
        )
      )

    # Get all tags from those photos, excluding tags from the original photo
    Repo.all(
      from(t in Tag,
        join: pt in PhotoTag,
        on: pt.tag_id == t.id,
        where: pt.photo_id in ^related_photos and t.id not in ^original_tag_ids
      )
    )
  end
end
