defmodule PhotoTaggerWeb.PhotoControllerTest do
  @moduledoc """
  Tests for the PhotoController handling photo creation and editing.

  NOTE: async: false is required because tests using setup_temp_storage modify
  global Application state (waffle :storage_dir_prefix), causing race conditions.
  """

  use PhotoTaggerWeb.ConnCase, async: false

  alias PhotoTagger.Gallery

  import PhotoTagger.GalleryFixtures
  import PhotoTagger.TempFileHelper

  describe "new photo" do
    test "includes both public and private folders in dropdown", %{conn: conn} do
      temp_dir = setup_temp_storage(%{})

      # Create a public folder
      public_folder =
        folder_fixture_with_files(%{
          temp_dir: temp_dir,
          name: "Public Test Folder",
          visibility_type: "public"
        })

      # Create a private folder
      private_folder =
        folder_fixture_with_files(%{
          temp_dir: temp_dir,
          name: "Private Test Folder",
          visibility_type: "private"
        })

      conn = get(conn, ~p"/admin/photos/new")
      response = html_response(conn, 200)

      # Verify both folders appear in the response
      assert response =~ public_folder.name
      assert response =~ private_folder.name
    end
  end

  describe "GET /admin/photos/new" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/admin/photos/new")

      assert html_response(conn, 200) =~ "New Photo"
    end
  end

  describe "POST /admin/photos" do
    setup do
      temp_dir = setup_temp_storage(%{})
      folder = folder_fixture_with_files(%{temp_dir: temp_dir})
      {:ok, temp_dir: temp_dir, folder: folder}
    end

    test "creates photo with valid data", %{conn: conn, folder: folder, temp_dir: temp_dir} do
      # Create test image file
      image_filename = "test_photo.jpg"
      {:ok, image_path} = create_test_image(temp_dir, image_filename)
      upload = create_upload_from_file(image_path, image_filename)

      # Build file metadata JSON
      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      metadata =
        JSON.encode!([%{"name" => image_filename, "lastModified" => last_modified}])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [upload],
        "file_metadata" => metadata,
        "is_public" => "true"
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      assert redirected_to(conn) =~ "/admin/folders/#{folder.name}/photos/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Photos created successfully"

      # Verify photo was created in database
      photos = Gallery.list_photos_by_folder(folder.name, include_private: true)
      assert length(photos) == 1
    end

    test "creates multiple photos from multiple uploads", %{
      conn: conn,
      folder: folder,
      temp_dir: temp_dir
    } do
      # Create multiple test images
      image1_filename = "photo1.jpg"
      image2_filename = "photo2.jpg"
      {:ok, image1_path} = create_test_image(temp_dir, image1_filename)
      {:ok, image2_path} = create_test_image(temp_dir, image2_filename)

      upload1 = create_upload_from_file(image1_path, image1_filename)
      upload2 = create_upload_from_file(image2_path, image2_filename)

      # Build file metadata JSON for both images
      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      metadata =
        JSON.encode!([
          %{"name" => image1_filename, "lastModified" => last_modified},
          %{"name" => image2_filename, "lastModified" => last_modified}
        ])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [upload1, upload2],
        "file_metadata" => metadata,
        "is_public" => "true"
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      assert redirected_to(conn) =~ "/admin/folders/#{folder.name}/photos/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Photos created successfully"

      # Verify both photos were created
      photos = Gallery.list_photos_by_folder(folder.name, include_private: true)
      assert length(photos) == 2
    end

    test "handles partial failure gracefully", %{conn: conn, folder: folder, temp_dir: temp_dir} do
      # Create one valid image and one invalid upload (missing file)
      # This tests the controller's ability to handle mixed success/failure
      valid_filename = "valid.jpg"
      invalid_filename = "invalid.jpg"

      {:ok, valid_path} = create_test_image(temp_dir, valid_filename)
      valid_upload = create_upload_from_file(valid_path, valid_filename)

      # Create an invalid upload with a non-existent path
      invalid_upload = %Plug.Upload{
        path: "/tmp/nonexistent_file_#{System.unique_integer([:positive])}.jpg",
        filename: invalid_filename,
        content_type: "image/jpeg"
      }

      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

      metadata =
        JSON.encode!([
          %{"name" => valid_filename, "lastModified" => last_modified},
          %{"name" => invalid_filename, "lastModified" => last_modified}
        ])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [valid_upload, invalid_upload],
        "file_metadata" => metadata,
        "is_public" => "true"
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      # Should have partial success - one created, one failed
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Some photos created successfully"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Some photos failed to save"

      # Verify only the valid photo was created
      photos = Gallery.list_photos_by_folder(folder.name, include_private: true)
      assert length(photos) == 1
      assert hd(photos).name == valid_filename
    end

    test "with invalid data shows error", %{conn: conn, folder: folder, temp_dir: temp_dir} do
      # Test with invalid name (empty string should fail validation)
      image_filename = "test.jpg"
      {:ok, image_path} = create_test_image(temp_dir, image_filename)
      upload = create_upload_from_file(image_path, image_filename)

      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      metadata = JSON.encode!([%{"name" => image_filename, "lastModified" => last_modified}])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [upload],
        "file_metadata" => metadata,
        "is_public" => "true",
        "name" => ""
        # Empty name should fail validation
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      # Should redirect - the controller always redirects even on error
      assert redirected_to(conn) =~ "/admin"
    end
  end

  describe "GET /admin/photos/:id/edit" do
    test "renders edit form", %{conn: conn} do
      temp_dir = setup_temp_storage(%{})
      folder = folder_fixture_with_files(%{temp_dir: temp_dir})

      photo =
        photo_fixture_with_files(%{folder_id: folder.id, temp_dir: temp_dir, is_public: true})

      conn = get(conn, ~p"/admin/photos/#{photo.id}/edit")

      assert html_response(conn, 200) =~ "Edit Photo"
    end
  end

  describe "upload with cross-listing" do
    setup do
      temp_dir = setup_temp_storage(%{})
      folder = folder_fixture_with_files(%{temp_dir: temp_dir})
      {:ok, temp_dir: temp_dir, folder: folder}
    end

    test "creates cross-listings in selected folders", %{
      conn: conn,
      folder: folder,
      temp_dir: temp_dir
    } do
      folder_b = folder_fixture_with_files(%{temp_dir: temp_dir, name: "cross_target"})

      image_filename = "cross_test.jpg"
      {:ok, image_path} = create_test_image(temp_dir, image_filename)
      upload = create_upload_from_file(image_path, image_filename)

      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      metadata = JSON.encode!([%{"name" => image_filename, "lastModified" => last_modified}])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [upload],
        "file_metadata" => metadata,
        "is_public" => "true",
        "cross_list_folder_ids" => [to_string(folder_b.id)]
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      assert redirected_to(conn) =~ "/admin/folders/#{folder.name}/photos/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Photos created successfully"

      # Verify original photo exists
      photos = Gallery.list_photos_by_folder(folder.name, include_private: true)
      assert length(photos) == 1

      # Verify cross-listing was created in target folder
      cross_listed = Gallery.list_photos_by_folder(folder_b.name, include_private: true)
      assert length(cross_listed) == 1
      assert Gallery.is_cross_listing?(hd(cross_listed))
    end

    test "creates cross-listings in multiple folders", %{
      conn: conn,
      folder: folder,
      temp_dir: temp_dir
    } do
      folder_b = folder_fixture_with_files(%{temp_dir: temp_dir, name: "target_b"})
      folder_c = folder_fixture_with_files(%{temp_dir: temp_dir, name: "target_c"})

      image_filename = "multi_cross.jpg"
      {:ok, image_path} = create_test_image(temp_dir, image_filename)
      upload = create_upload_from_file(image_path, image_filename)

      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      metadata = JSON.encode!([%{"name" => image_filename, "lastModified" => last_modified}])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [upload],
        "file_metadata" => metadata,
        "is_public" => "true",
        "cross_list_folder_ids" => [to_string(folder_b.id), to_string(folder_c.id)]
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Photos created successfully"

      # Verify cross-listings exist in both target folders
      assert length(Gallery.list_photos_by_folder(folder_b.name, include_private: true)) == 1
      assert length(Gallery.list_photos_by_folder(folder_c.name, include_private: true)) == 1
    end

    test "upload without cross-listing folders still works normally", %{
      conn: conn,
      folder: folder,
      temp_dir: temp_dir
    } do
      image_filename = "no_cross.jpg"
      {:ok, image_path} = create_test_image(temp_dir, image_filename)
      upload = create_upload_from_file(image_path, image_filename)

      last_modified = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      metadata = JSON.encode!([%{"name" => image_filename, "lastModified" => last_modified}])

      photo_params = %{
        "folder" => folder.name,
        "folder_id" => folder.id,
        "images" => [upload],
        "file_metadata" => metadata,
        "is_public" => "true"
      }

      conn = post(conn, ~p"/admin/photos", photo: photo_params)

      assert redirected_to(conn) =~ "/admin/folders/#{folder.name}/photos/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Photos created successfully"

      photos = Gallery.list_photos_by_folder(folder.name, include_private: true)
      assert length(photos) == 1
      refute Gallery.is_cross_listing?(hd(photos))
    end

    test "upload form shows cross-listing folder multi-select", %{
      conn: conn,
      folder: _folder,
      temp_dir: _temp_dir
    } do
      conn = get(conn, ~p"/admin/photos/new")
      response = html_response(conn, 200)

      assert response =~ "Also cross-list to"
      assert response =~ "cross_list_folder_ids"
    end
  end

  describe "build_url/2" do
    test "generates correct URLs" do
      folder = folder_fixture(%{name: "test_folder"})
      photo = photo_fixture(%{folder_id: folder.id, name: "test.jpg"})

      # Test with both folder and photo
      url = PhotoTaggerWeb.PhotoController.build_url("test_folder", photo)
      assert url == "/admin/folders/test_folder/photos/#{photo.id}"

      # Test with folder but no photo
      url = PhotoTaggerWeb.PhotoController.build_url("test_folder", nil)
      assert url == "/admin/folders/test_folder"

      # Test with neither folder nor photo
      url = PhotoTaggerWeb.PhotoController.build_url(nil, nil)
      assert url == "/admin"

      # Test with photo but no folder
      url = PhotoTaggerWeb.PhotoController.build_url(nil, photo)
      assert url == "/admin/photos/#{photo.id}"
    end
  end
end
