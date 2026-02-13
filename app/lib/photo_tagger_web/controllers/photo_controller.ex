defmodule PhotoTaggerWeb.PhotoController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Repo
  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo

  def build_url(folder, photo) do
    uri = URI.new!("/admin")
    uri = if(folder, do: URI.append_path(uri, "/folders/#{folder}"), else: uri)
    uri = if(photo, do: URI.append_path(uri, "/photos/#{photo.id}"), else: uri)
    URI.to_string(uri)
  end

  def new(conn, _params) do
    changeset = Gallery.new_photo_changeset(%Photo{})
    folders = Gallery.list_folders(include_private: true)
    render(conn, :new, %{changeset: changeset, folders: folders})
  end

  def create(conn, %{"photo" => photo_params}) do
    {extracted, other_params} =
      Map.split(photo_params, ["images", "file_metadata", "cross_list_folder_ids"])

    images = extracted["images"]
    metadata_string = extracted["file_metadata"]
    cross_list_folder_ids =
      (extracted["cross_list_folder_ids"] || [])
      |> Enum.map(&String.to_integer/1)

    metadata = JSON.decode!(metadata_string)
    folder = other_params["folder"]

    photo_attrs =
      Enum.map(images, fn image ->
        other_params
        |> Map.put("image", image)
        |> Map.put(
          "image_last_modified",
          Enum.find(metadata, &(&1["name"] == image.filename))
          |> Map.get("lastModified")
          |> DateTime.from_unix!(:millisecond)
        )
      end)

    results = Enum.map(photo_attrs, &Gallery.create_photo(&1))
    successful_photos = for {:ok, photo} <- results, do: photo

    # Create cross-listings for each successfully created photo
    Enum.each(successful_photos, fn photo ->
      Enum.each(cross_list_folder_ids, fn folder_id ->
        Gallery.create_cross_listing(photo, folder_id)
      end)
    end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      url = build_url(folder, List.first(results) |> elem(1))

      conn
      |> put_flash(:info, "Photos created successfully.")
      |> redirect(to: url)
    else
      failed_photos = for {:error, changeset} <- results, do: changeset.changes.name
      # {Keyword.get(changeset.errors, :image) |> elem(0)}"
      url =
        if(Enum.empty?(successful_photos),
          do: build_url(folder, nil),
          else: build_url(folder, List.first(successful_photos))
        )

      successful_photo_names = Enum.map(successful_photos, & &1.name) |> Enum.join(", ")

      conn =
        if(Enum.empty?(successful_photos),
          do: conn,
          else:
            conn
            |> put_flash(:info, "Some photos created successfully: #{successful_photo_names}")
        )

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
    photo = Gallery.get_photo!(id, include_private: true)
    photo = Repo.preload(photo, [:tags])
    changeset = Gallery.update_photo_changeset(photo)
    folders = Gallery.list_folders()
    render(conn, :edit, photo: photo, changeset: changeset, folders: folders)
  end
end
