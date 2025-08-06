defmodule PhotoTaggerWeb.FolderController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Gallery

  def index(conn, _params) do
    folders = Gallery.list_folders()
    render(conn, :index, folders: folders)
  end

  def create(conn, %{"name" => name, "is_public" => is_public} = attrs) do
    result = Gallery.create_folder(attrs)

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder created successfully.")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(
          :error,
          "Failed to create folder! Error #{failed_value} in step #{failed_op}."
        )
        |> redirect(to: ~p"/admin/edit-folders")
    end
  end

  def edit_folders(conn, _params) do
    folders = Gallery.list_folders(include_private: true)
    render(conn, :edit_folders, folders: folders)
  end

  def update(conn, %{"name" => name, "is_public" => is_public, "folder" => folder} = attrs) do
    folder = Gallery.get_folder_by_name!(folder)
    result = Gallery.update_folder(folder, Map.take(attrs, ["is_public", "name"]))

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder updated successfully.")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(
          :error,
          "Failed to update folder! Error #{failed_value} in step #{failed_op}."
        )
        |> redirect(to: ~p"/admin/edit-folders")
    end
  end

  def rename(conn, %{"folder" => folder, "new_name" => new_name}) do
    result = Gallery.rename_folder(folder, new_name)

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder renamed successfully.")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(
          :error,
          "Failed to rename folder! Error #{failed_value} in step #{failed_op}."
        )
        |> redirect(to: ~p"/admin/edit-folders")
    end
  end

  def delete(conn, %{"folder" => folder}) do
    result = Gallery.delete_folder(folder)

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder deleted successfully.")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(
          :error,
          "Failed to delete folder! Error #{failed_value} in step #{failed_op}."
        )
        |> redirect(to: ~p"/admin/edit-folders")
    end
  end
end
