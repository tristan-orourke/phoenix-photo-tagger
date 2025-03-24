defmodule PhotoTaggerWeb.FolderController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Gallery

  def edit_folders(conn, _params) do
    folders = Gallery.list_folders()
    render(conn, :edit_folders, folders: folders)
  end

  def rename(conn, %{"folder" => folder, "new_name" => new_name}) do
    result = Gallery.rename_folder(folder, new_name)

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder renamed successfully.")
        |> redirect(to: ~p"/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(
          :error,
          "Failed to rename folder! Error #{failed_value} in step #{failed_op}."
        )
        |> redirect(to: ~p"/edit-folders")
    end
  end

  def delete(conn, %{"folder" => folder}) do
    result = Gallery.delete_folder(folder)

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder deleted successfully.")
        |> redirect(to: ~p"/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        conn
        |> put_flash(
          :error,
          "Failed to delete folder! Error #{failed_value} in step #{failed_op}."
        )
        |> redirect(to: ~p"/edit-folders")
    end
  end
end
