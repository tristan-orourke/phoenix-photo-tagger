defmodule PhotoTaggerWeb.FolderControllerTest do
	@moduledoc """
	Tests for the FolderController handling folder CRUD operations.

	NOTE: async: false is required because tests using setup_temp_storage modify
	global Application state (waffle :storage_dir_prefix), causing race conditions.
	"""

	use PhotoTaggerWeb.ConnCase, async: false

	alias PhotoTagger.Gallery

	import PhotoTagger.GalleryFixtures
	import PhotoTagger.TempFileHelper

	describe "GET /admin/edit-folders" do
		test "renders folder list", %{conn: conn} do
			folder = folder_fixture(%{name: "test_folder"})

			conn = get(conn, ~p"/admin/edit-folders")

			assert html_response(conn, 200) =~ "Edit Folders"
			assert html_response(conn, 200) =~ folder.name
		end
	end

	describe "POST /admin/folders" do
		setup do
			temp_dir = setup_temp_storage(%{})
			{:ok, temp_dir: temp_dir}
		end

		test "creates folder with valid data", %{conn: conn} do
			folder_name = "new_folder_#{System.unique_integer([:positive])}"

			folder_params = %{
				"name" => folder_name,
				"is_public" => "true"
			}

			conn = post(conn, ~p"/admin/folders", folder_params)

			assert redirected_to(conn) == ~p"/admin/edit-folders"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Folder created successfully"

			# Verify folder was created in database
			folder = Gallery.get_folder_by_name!(folder_name)
			assert folder.name == folder_name
			assert folder.is_public == true
		end

		test "with duplicate name shows error", %{conn: conn} do
			# Create a folder first
			folder = folder_fixture(%{name: "duplicate_test"})

			# Try to create another folder with same name - should show proper error
			folder_params = %{
				"name" => folder.name,
				"is_public" => "true"
			}

			conn = post(conn, ~p"/admin/folders", folder_params)

			assert redirected_to(conn) == ~p"/admin/edit-folders"
			assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to create folder"
			assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "has already been taken"
		end
	end

	describe "PUT /admin/folders/:folder" do
		test "updates folder", %{conn: conn} do
			folder = folder_fixture(%{name: "update_test", is_public: true})

			update_params = %{
				"folder" => folder.name,
				"name" => folder.name,
				"is_public" => "false"
			}

			conn = put(conn, ~p"/admin/folders/#{folder.name}", update_params)

			assert redirected_to(conn) == ~p"/admin/edit-folders"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Folder updated successfully"

			# Verify folder was updated
			updated_folder = Gallery.get_folder_by_name!(folder.name)
			assert updated_folder.is_public == false
		end

		test "with name change renames directory", %{conn: conn} do
			temp_dir = setup_temp_storage(%{})
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "old_name"})

			new_name = "new_name_#{System.unique_integer([:positive])}"

			update_params = %{
				"folder" => folder.name,
				"name" => new_name,
				"is_public" => "true"
			}

			conn = put(conn, ~p"/admin/folders/#{folder.name}", update_params)

			assert redirected_to(conn) == ~p"/admin/edit-folders"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Folder updated successfully"

			# Verify folder was renamed in database
			renamed_folder = Gallery.get_folder_by_name!(new_name)
			assert renamed_folder.name == new_name

			# Verify old name no longer exists
			assert_raise Ecto.NoResultsError, fn ->
				Gallery.get_folder_by_name!(folder.name)
			end
		end
	end

	describe "POST /admin/folders/:folder/rename" do
		test "renames folder", %{conn: conn} do
			temp_dir = setup_temp_storage(%{})
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "rename_test"})

			new_name = "renamed_#{System.unique_integer([:positive])}"

			rename_params = %{
				"folder" => folder.name,
				"new_name" => new_name
			}

			conn = post(conn, ~p"/admin/folders/#{folder.name}/rename", rename_params)

			assert redirected_to(conn) == ~p"/admin/edit-folders"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Folder renamed successfully"

			# Verify folder was renamed
			renamed_folder = Gallery.get_folder_by_name!(new_name)
			assert renamed_folder.name == new_name
		end
	end

	describe "DELETE /admin/folders/:folder" do
		test "deletes folder", %{conn: conn} do
			temp_dir = setup_temp_storage(%{})
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "delete_test"})

			# Add a photo to the folder to verify cascade deletion
			_photo = photo_fixture_with_files(%{folder_id: folder.id, temp_dir: temp_dir})

			conn = delete(conn, ~p"/admin/folders/#{folder.name}")

			assert redirected_to(conn) == ~p"/admin/edit-folders"
			assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Folder deleted successfully"

			# Verify folder was deleted
			assert_raise Ecto.NoResultsError, fn ->
				Gallery.get_folder_by_name!(folder.name)
			end
		end
	end
end
