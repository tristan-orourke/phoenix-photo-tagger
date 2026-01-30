defmodule PhotoTaggerWeb.FolderController do
  use PhotoTaggerWeb, :controller

  alias PhotoTagger.Gallery

  def index(conn, _params) do
    folders = Gallery.list_folders()
    render(conn, :index, folders: folders)
  end

  def create(conn, %{"name" => _name, "is_public" => _is_public} = attrs) do
    result = Gallery.create_folder(attrs)

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder created successfully.")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, _failed_op, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        # Extract human-readable error from changeset
        error_msg =
          case changeset.errors do
            [{field, {msg, _}} | _] -> "#{field} #{msg}"
            _ -> "validation failed"
          end

        conn
        |> put_flash(:error, "Failed to create folder: #{error_msg}")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        # Handle non-changeset errors (file system errors, etc.)
        conn
        |> put_flash(:error, "Failed to create folder: #{inspect(failed_value)} in step #{failed_op}")
        |> redirect(to: ~p"/admin/edit-folders")
    end
  end

  def edit_folders(conn, _params) do
    folders = Gallery.list_folders(include_private: true)
    render(conn, :edit_folders, folders: folders)
  end

  def update(conn, %{"name" => _name, "is_public" => _is_public, "folder" => folder} = attrs) do
    folder = Gallery.get_folder_by_name!(folder)
    result = Gallery.update_folder(folder, Map.take(attrs, ["is_public", "name"]))

    case result do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Folder updated successfully.")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, _failed_op, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        # Extract human-readable error from changeset
        error_msg =
          case changeset.errors do
            [{field, {msg, _}} | _] -> "#{field} #{msg}"
            _ -> "validation failed"
          end

        conn
        |> put_flash(:error, "Failed to update folder: #{error_msg}")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        # Handle non-changeset errors (file system errors, etc.)
        conn
        |> put_flash(:error, "Failed to update folder: #{inspect(failed_value)} in step #{failed_op}")
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

      {:error, _failed_op, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        # Extract human-readable error from changeset
        error_msg =
          case changeset.errors do
            [{field, {msg, _}} | _] -> "#{field} #{msg}"
            _ -> "validation failed"
          end

        conn
        |> put_flash(:error, "Failed to rename folder: #{error_msg}")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        # Handle non-changeset errors (file system errors, etc.)
        conn
        |> put_flash(:error, "Failed to rename folder: #{inspect(failed_value)} in step #{failed_op}")
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

      {:error, _failed_op, %Ecto.Changeset{} = changeset, _changes_so_far} ->
        # Extract human-readable error from changeset
        error_msg =
          case changeset.errors do
            [{field, {msg, _}} | _] -> "#{field} #{msg}"
            _ -> "validation failed"
          end

        conn
        |> put_flash(:error, "Failed to delete folder: #{error_msg}")
        |> redirect(to: ~p"/admin/edit-folders")

      {:error, failed_op, failed_value, _changes_so_far} ->
        # Handle non-changeset errors (file system errors, etc.)
        conn
        |> put_flash(:error, "Failed to delete folder: #{inspect(failed_value)} in step #{failed_op}")
        |> redirect(to: ~p"/admin/edit-folders")
    end
  end
end
