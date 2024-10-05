defmodule PhotoTaggerWeb.PhotoController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Gallery
  alias PhotoTagger.Gallery.Photo

  def index(conn, _params) do
    photos = Gallery.list_photos()
    render(conn, :index, photos: photos)
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
    photo = Gallery.get_photo!(id)
    IO.inspect(photo)
    render(conn, :show, photo: photo)
  end

  def edit(conn, %{"id" => id}) do
    photo = Gallery.get_photo!(id)
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
end
