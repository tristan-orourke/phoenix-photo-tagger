defmodule PhotoTaggerWeb.PhotoController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo

  def build_url(folder, photo, tags, tail \\ nil) do
    uri = URI.new!("/")
    uri = if(folder, do: URI.append_path(uri, "/folders/#{folder}"), else: uri)
    uri = if(photo, do: URI.append_path(uri, "/photos/#{photo.id}"), else: uri)
    uri = if(tail, do: URI.append_path(uri, tail), else: uri)

    query = Plug.Conn.Query.encode(%{query_tags: tags})
    uri = if(!Enum.empty?(tags), do: URI.append_query(uri, query), else: uri)

    URI.to_string(uri)
  end

  def new(conn, _params) do
    changeset = Gallery.new_photo_changeset(%Photo{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"photo" => photo_params}) do
    %{"folder" => folder, "images" => images, "file_metadata" => metadata_string} = photo_params
    metadata = JSON.decode!(metadata_string)
    photo_attrs = Enum.map(images, fn image -> %{
      "folder" => folder,
      "image" => image,
      "image_last_modified" =>
        Enum.find(metadata, &(&1["name"] == image.filename))
        |> Map.get("lastModified")
        |> DateTime.from_unix!(:millisecond)
    } end)
    results = Enum.map(photo_attrs, &Gallery.create_photo(&1))
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
