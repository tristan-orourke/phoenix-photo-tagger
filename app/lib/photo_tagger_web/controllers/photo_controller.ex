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
      |> Enum.sort_by(& &1.name)

    all_folders = Gallery.list_folders_include_tags()
    all_tags = Gallery.list_tags()

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
end
