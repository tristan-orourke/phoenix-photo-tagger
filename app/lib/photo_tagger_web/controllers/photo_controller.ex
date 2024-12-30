defmodule PhotoTaggerWeb.PhotoController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo

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
    render(conn, :main, state)
  end

  def folders(conn, _params) do
    state = expand_state(%{folder: nil, tags: [], photo_id: nil})
    render(conn, :main, state)
  end

  def index(conn, %{"query_tags" => tags}) when is_list(tags) do
    state = expand_state(%{folder: nil, tags: tags, photo_id: nil})
    render(conn, :main, state)
  end

  def index(conn, %{"query_tags" => tag}) do
    state = expand_state(%{folder: nil, tags: [tag], photo_id: nil})
    render(conn, :main, state)
  end

  def index(conn, _params) do
    state = expand_state(%{folder: nil, tags: [], photo_id: nil})
    render(conn, :main, state)
  end

  def new(conn, _params) do
    changeset = Gallery.change_photo(%Photo{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"photo" => photo_params}) do
    case Gallery.create_photo(photo_params) do
      {:ok, photo} ->
        conn
        |> put_flash(:info, "Photo created successfully.")
        |> redirect(to: ~p"/photos/#{photo}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    state = expand_state(%{folder: nil, tags: [], photo_id: id})
    render(conn, :main, state)
  end

  def edit(conn, %{"id" => id}) do
    photo = Gallery.get_photo!(id)
    photo = Repo.preload(photo, :tags)
    changeset = Gallery.change_photo(photo)
    render(conn, :edit, photo: photo, changeset: changeset)
  end

  def update(conn, %{"id" => id, "photo" => photo_params}) do
    photo = Gallery.get_photo!(id)

    case Gallery.update_photo(photo, photo_params) do
      {:ok, photo} ->
        conn
        |> put_flash(:info, "Photo updated successfully.")
        |> redirect(to: ~p"/photos/#{photo}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, photo: photo, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    photo = Gallery.get_photo!(id)
    {:ok, _photo} = Gallery.delete_photo(photo)

    conn
    |> put_flash(:info, "Photo deleted successfully.")
    |> redirect(to: ~p"/photos")
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
end
