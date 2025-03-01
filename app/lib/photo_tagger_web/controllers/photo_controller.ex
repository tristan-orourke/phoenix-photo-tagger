defmodule PhotoTaggerWeb.PhotoController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo
  require Logger

  def build_url(folder, photo, tags, tail \\ nil) do
    uri = URI.new!("/")
    uri = if(folder, do: URI.append_path(uri, "/folders/#{folder}"), else: uri)
    uri = if(photo, do: URI.append_path(uri, "/photos/#{photo.id}"), else: uri)
    uri = if(tail, do: URI.append_path(uri, tail), else: uri)

    query = Plug.Conn.Query.encode(%{query_tags: tags})
    uri = if(!Enum.empty?(tags), do: URI.append_query(uri, query), else: uri)

    URI.to_string(uri)
  end

  def build_cannonical_photo_url(folder, photo, tags, tail \\ nil) do
    uri = URI.new!("/photos/#{photo.id}")
    uri = if(tail, do: URI.append_path(uri, tail), else: uri)

    tags_query = Plug.Conn.Query.encode(%{query_tags: tags})
    uri = if(!Enum.empty?(tags), do: URI.append_query(uri, tags_query), else: uri)

    folder_query = Plug.Conn.Query.encode(%{folder: folder})
    uri = if(folder, do: URI.append_query(uri, folder_query), else: uri)

    URI.to_string(uri)
  end

  def expand_state(%{folder: folder, tags: tags, photo_id: photo_id}) do
    filtered_photos =
      case {folder, tags} do
        {nil, []} -> Gallery.list_photos()
        {nil, tags} -> Gallery.list_photos_by_all_tags(tags)
        {folder, []} -> Gallery.list_photos_by_folder(folder)
        {folder, tags} -> Gallery.list_photos_by_folder_and_tags(folder, tags)
      end
    filtered_photos = Repo.preload(filtered_photos, :tags)

    photo =
      case photo_id do
        nil ->
          nil

        id ->
          p = Gallery.get_photo!(id)
          Repo.preload(p, :tags)
      end

    recommended_tags =
      Enum.reduce(filtered_photos, MapSet.new(), fn photo, acc ->
        MapSet.union(acc, MapSet.new(photo.tags))
      end)
      |> MapSet.to_list()

    all_folders = Gallery.list_folders_include_tags()
    all_tags = Gallery.list_tags() |> Enum.map(&(&1.name))

    %{
      folder: folder,
      all_folders: all_folders,
      tags: tags,
      all_tags: all_tags,
      photo: photo,
      filtered_photos: filtered_photos,
      recommended_tags: recommended_tags
    }
  end

  def main(conn, params) do
    tags = Map.get(params, "query_tags", [])
    tags = if is_list(tags), do: tags, else: [tags]

    state = expand_state(%{folder: Map.get(params, "folder"), tags: tags, photo_id: Map.get(params, "photo_id")})
    conn
    |> render(:main, state)
  end

  def new(conn, _params) do
    changeset = Gallery.new_photo_changeset(%Photo{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"photo" => photo_params}) do
    %{"folder" => folder, "images" => images} = photo_params
    results = Enum.map(images, fn image -> Gallery.create_photo(%{"folder" => folder, "image" => image}) end)
    if Enum.all?(results, fn {:ok, _} -> true; _ -> false end) do
      url = build_url(folder, List.first(results) |> elem(1), [])
      conn
      |> put_flash(:info, "Photos created successfully.")
      |> redirect(to: url)
    else
      successful_photos = for {:ok, photo} <- results, do: photo
      failed_photos = for {:error, changeset} <- results, do: changeset.changes.name
      #{Keyword.get(changeset.errors, :image) |> elem(0)}"
      url = if(Enum.empty?(successful_photos), do: build_url(folder, nil, []), else: build_url(folder, List.first(successful_photos), []))
      successful_photo_names = Enum.map(successful_photos, &(&1.name)) |> Enum.join(", ")
      conn = if(Enum.empty?(successful_photos), do: conn, else: conn |> put_flash(:info, "Some photos created successfully: #{successful_photo_names}"))
      conn
      |> put_flash(:error, "Some photos failed to save: #{Enum.join(failed_photos, ", ")}")
      |> redirect(to: url)
    end
    # case Gallery.create_photo(photo_params) do
    #   {:ok, photo} ->
    #     conn
    #     |> put_flash(:info, "Photo created successfully.")
    #     |> redirect(to: ~p"/photos/#{photo}")

    #   {:error, %Ecto.Changeset{} = changeset} ->
    #     render(conn, :new, changeset: changeset)
    # end
  end

  def edit(conn, %{"id" => id}) do
    photo = Gallery.get_photo!(id)
    photo = Repo.preload(photo, :tags)
    changeset = Gallery.update_photo_changeset(photo)
    render(conn, :edit, photo: photo, changeset: changeset)
  end

  def update(conn, %{"id" => id, "photo" => photo_params} = params) do
    photo = Gallery.get_photo!(id)

    tags = Map.get(params, "query_tags", [])
    tags = if is_list(tags), do: tags, else: [tags]
    url = build_url(Map.get(params, "folder"), photo, tags)

    case Gallery.update_photo(photo, photo_params) do
      {:ok, photo} ->
        conn
        |> put_flash(:info, "Photo updated successfully.")
        |> redirect(to: url)

      {:error, failed_op, failed_value, changeset} ->
        conn
        |> put_flash(:error, "Failed to update photo. Error #{failed_value} in step #{failed_op}.")
        |> redirect(to: url)
    end
  end

  def delete(conn, %{"id" => id} = params) do
    photo = Gallery.get_photo!(id)
    {:ok, _photo} = Gallery.delete_photo(photo)

    tags = Map.get(params, "query_tags", [])
    tags = if is_list(tags), do: tags, else: [tags]
    url = build_url(Map.get(params, "folder"), nil, tags)

    conn
    |> put_flash(:info, "Photo deleted successfully.")
    |> redirect(to: url)
  end

  def add_tag_main(conn, %{"photo_id" => photo_id, "tag" => tag} = params) do
    photo = Gallery.get_photo!(photo_id)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag)

    tags = Map.get(params, "query_tags", [])
    tags = if is_list(tags), do: tags, else: [tags]
    tags = Enum.uniq(tags ++ [tag])

    conn
    |> redirect(to: build_url(Map.get(params, "folder"), photo, tags))
  end

  def remove_tag_main(conn, %{"photo_id" => photo_id, "tag" => tag} = params) do
    photo = Gallery.get_photo!(photo_id)
    {:ok, _} = Gallery.remove_tag_from_photo(photo, tag)

    tags = Map.get(params, "query_tags", [])
    tags = if is_list(tags), do: tags, else: [tags]
    tags = Enum.filter(tags, &(&1 != tag))

    conn
    |> redirect(to: build_url(Map.get(params, "folder"), photo, tags))
  end


  def add_tag(conn, %{"id" => id, "tag" => tag}) do
    photo = Gallery.get_photo!(id)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag)

    conn
    |> put_flash(:info, "Tag added successfully.")
    |> redirect(to: ~p"/photos/#{photo}/edit")
  end

  def remove_tag(conn, %{"id" => id, "tag" => tag}) do
    photo = Gallery.get_photo!(id)
    Gallery.remove_tag_from_photo(photo, tag)

    conn
    |> put_flash(:info, "Tag removed successfully.")
    |> redirect(to: ~p"/photos/#{photo}/edit")
  end

  def edit_folders(conn, _params) do
    folders = Gallery.list_folders()
    render(conn, :edit_folders, folders: folders)
  end

  def rename_folder(conn, %{"folder" => folder, "new_name" => new_name}) do
    result = Gallery.rename_folder(folder, new_name)
    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder renamed successfully.")
        |> redirect(to: ~p"/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(:error, "Failed to rename folder! Error #{failed_value} in step #{failed_op}.")
        |> redirect(to: ~p"/edit-folders")
    end
  end

  def delete_folder(conn, %{"folder" => folder}) do
    result = Gallery.delete_folder(folder)
    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder deleted successfully.")
        |> redirect(to: ~p"/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(:error, "Failed to delete folder! Error #{failed_value} in step #{failed_op}.")
        |> redirect(to: ~p"/edit-folders")
    end
  end
end
