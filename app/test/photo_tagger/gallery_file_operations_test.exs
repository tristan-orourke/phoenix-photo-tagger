defmodule PhotoTagger.GalleryFileOperationsTest do
  @moduledoc """
  Tests for filesystem operations in the Gallery context.
  All tests use real temp directories and files.

  NOTE: async: false is required because these tests modify global Application
  state (waffle :storage_dir_prefix). Running async causes race conditions where
  tests overwrite each other's storage directories, leading to file-not-found errors.
  """

  use PhotoTagger.DataCase, async: false

  alias PhotoTagger.Gallery
  alias PhotoTagger.Uploaders.ImageUploader

  import PhotoTagger.GalleryFixtures

  alias PhotoTagger.TempFileHelper

  describe "photo file storage" do
    setup do
      temp_dir = TempFileHelper.setup_temp_storage(%{})
      folder = folder_fixture_with_files(%{temp_dir: temp_dir})
      {:ok, temp_dir: temp_dir, folder: folder}
    end

    test "create_photo/1 stores all image versions", %{temp_dir: temp_dir, folder: folder} do
      photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

      assert TempFileHelper.image_exists?(photo, :original)
      assert TempFileHelper.image_exists?(photo, :thumb)
      assert TempFileHelper.image_exists?(photo, :web_md)
      assert TempFileHelper.image_exists?(photo, :web_lg)
    end

    test "create_photo/1 stores images in correct folder path", %{
      temp_dir: temp_dir,
      folder: folder
    } do
      photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

      original_path = TempFileHelper.get_image_path(photo, :original)
      expected_folder_path = Path.join([temp_dir, "uploads/images", folder.name])

      assert String.starts_with?(original_path, expected_folder_path)
    end

    test "create_photo/1 generates correct filenames for each version", %{
      temp_dir: temp_dir,
      folder: folder
    } do
      photo =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder.id,
          name: "test_photo.jpg"
        })

      original_path = TempFileHelper.get_image_path(photo, :original)
      thumb_path = TempFileHelper.get_image_path(photo, :thumb)
      web_md_path = TempFileHelper.get_image_path(photo, :web_md)
      web_lg_path = TempFileHelper.get_image_path(photo, :web_lg)

      # Original keeps extension, others use .webp
      assert String.ends_with?(original_path, "test_photo.jpg")
      assert String.ends_with?(thumb_path, "test_photo.thumb.webp")
      assert String.ends_with?(web_md_path, "test_photo.web_md.webp")
      assert String.ends_with?(web_lg_path, "test_photo.web_lg.webp")
    end
  end

  describe "photo file operations" do
    setup do
      temp_dir = TempFileHelper.setup_temp_storage(%{})
      folder = folder_fixture_with_files(%{temp_dir: temp_dir})
      {:ok, temp_dir: temp_dir, folder: folder}
    end

    test "update_photo/2 renames all image versions when name changes", %{
      temp_dir: temp_dir,
      folder: folder
    } do
      photo =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder.id,
          name: "old_name.jpg"
        })

      # Get old paths for all versions
      old_original = TempFileHelper.get_image_path(photo, :original)
      old_thumb = TempFileHelper.get_image_path(photo, :thumb)

      # Verify old files exist
      assert File.exists?(old_original)
      assert File.exists?(old_thumb)

      # Update name
      {:ok, multi_result} = Gallery.update_photo(photo, %{"name" => "new_name.jpg"})

      # Reload to get updated image field
      updated_photo = Gallery.get_photo!(multi_result.photo.id, include_private: true)

      # Get new paths
      new_original = TempFileHelper.get_image_path(updated_photo, :original)
      new_thumb = TempFileHelper.get_image_path(updated_photo, :thumb)

      # Verify old files are gone
      refute File.exists?(old_original)
      refute File.exists?(old_thumb)

      # Verify new files exist
      assert File.exists?(new_original)
      assert File.exists?(new_thumb)
    end

    test "update_photo/2 moves images when folder changes", %{temp_dir: temp_dir, folder: folder} do
      # Create another folder
      folder2 = folder_fixture_with_files(%{temp_dir: temp_dir, name: "folder2"})

      # Create photo in first folder
      photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

      # Get old paths for all versions
      old_original = TempFileHelper.get_image_path(photo, :original)
      old_thumb = TempFileHelper.get_image_path(photo, :thumb)

      # Verify old files exist
      assert File.exists?(old_original)
      assert File.exists?(old_thumb)

      # Move to second folder
      {:ok, multi_result} = Gallery.update_photo(photo, %{"folder_id" => folder2.id})

      # Reload to get updated folder association
      updated_photo = Gallery.get_photo!(multi_result.photo.id, include_private: true)

      # Get new paths
      new_original = TempFileHelper.get_image_path(updated_photo, :original)
      new_thumb = TempFileHelper.get_image_path(updated_photo, :thumb)

      # Verify old files are gone
      refute File.exists?(old_original)
      refute File.exists?(old_thumb)

      # Verify new files exist in new folder
      assert File.exists?(new_original)
      assert File.exists?(new_thumb)
      assert String.contains?(new_original, "folder2")
    end

    test "delete_photo/1 removes all image versions from filesystem", %{
      temp_dir: temp_dir,
      folder: folder
    } do
      photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

      # Get paths
      original_path = TempFileHelper.get_image_path(photo, :original)
      thumb_path = TempFileHelper.get_image_path(photo, :thumb)
      web_md_path = TempFileHelper.get_image_path(photo, :web_md)
      web_lg_path = TempFileHelper.get_image_path(photo, :web_lg)

      # Verify files exist
      assert File.exists?(original_path)
      assert File.exists?(thumb_path)
      assert File.exists?(web_md_path)
      assert File.exists?(web_lg_path)

      # Delete photo
      {:ok, _multi_result} = Gallery.delete_photo(photo)

      # Verify files are gone
      refute File.exists?(original_path)
      refute File.exists?(thumb_path)
      refute File.exists?(web_md_path)
      refute File.exists?(web_lg_path)
    end
  end

  describe "folder file operations" do
    setup do
      temp_dir = TempFileHelper.setup_temp_storage(%{})
      {:ok, temp_dir: temp_dir}
    end

    test "create_folder/1 creates directory at correct path", %{temp_dir: temp_dir} do
      folder = folder_fixture_with_files(%{temp_dir: temp_dir})

      folder_path = TempFileHelper.get_folder_path(folder)
      expected_path = Path.join([temp_dir, "uploads/images", folder.name])

      assert folder_path == expected_path
      assert File.dir?(folder_path)
    end

    test "update_folder/2 renames directory when name changes", %{temp_dir: temp_dir} do
      folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "old_folder"})

      old_path = TempFileHelper.get_folder_path(folder)
      assert File.dir?(old_path)

      # Rename folder
      {:ok, multi_result} = Gallery.update_folder(folder, %{"name" => "new_folder"})

      new_path = TempFileHelper.get_folder_path(multi_result.update_folder_db)

      # Verify old directory is gone and new directory exists
      refute File.dir?(old_path)
      assert File.dir?(new_path)
    end

    test "update_folder/2 updates photo image paths", %{temp_dir: temp_dir} do
      folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "old_folder"})
      photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

      # Get old photo path
      old_photo_path = TempFileHelper.get_image_path(photo, :original)
      assert File.exists?(old_photo_path)
      assert String.contains?(old_photo_path, "old_folder")

      # Rename folder
      {:ok, _updated_folder} = Gallery.update_folder(folder, %{"name" => "new_folder"})

      # Reload photo
      updated_photo = Gallery.get_photo!(photo.id, include_private: true)

      # Get new photo path
      new_photo_path = TempFileHelper.get_image_path(updated_photo, :original)

      # Verify photo is in new folder path and file exists
      assert String.contains?(new_photo_path, "new_folder")
      assert File.exists?(new_photo_path)
      refute File.exists?(old_photo_path)
    end

    test "delete_folder/1 removes directory and all contents", %{temp_dir: temp_dir} do
      folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "doomed_folder"})

      # Create a couple photos in the folder
      photo1 = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})
      photo2 = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

      folder_path = TempFileHelper.get_folder_path(folder)
      photo1_path = TempFileHelper.get_image_path(photo1, :original)
      photo2_path = TempFileHelper.get_image_path(photo2, :original)

      # Verify folder and files exist
      assert File.dir?(folder_path)
      assert File.exists?(photo1_path)
      assert File.exists?(photo2_path)

      # Delete folder (expects folder name, not folder struct)
      {:ok, _multi_result} = Gallery.delete_folder(folder.name)

      # Verify directory is completely gone
      refute File.dir?(folder_path)
      refute File.exists?(photo1_path)
      refute File.exists?(photo2_path)
    end
  end

  describe "ImageUploader validation" do
    test "validate/1 accepts valid extensions" do
      valid_extensions = [".jpg", ".jpeg", ".png", ".gif"]

      for ext <- valid_extensions do
        file = %{file_name: "test#{ext}"}
        assert ImageUploader.validate({file, nil}) == :ok
      end
    end

    test "validate/1 rejects invalid extensions" do
      invalid_extensions = [".txt", ".pdf", ".doc", ".mp4", ".zip"]

      for ext <- invalid_extensions do
        file = %{file_name: "test#{ext}"}
        assert ImageUploader.validate({file, nil}) == {:error, "invalid file type"}
      end
    end

    test "validate/1 is case insensitive" do
      # Test uppercase extensions
      file = %{file_name: "test.JPG"}
      assert ImageUploader.validate({file, nil}) == :ok

      file = %{file_name: "test.JPEG"}
      assert ImageUploader.validate({file, nil}) == :ok

      file = %{file_name: "test.PNG"}
      assert ImageUploader.validate({file, nil}) == :ok

      file = %{file_name: "test.GIF"}
      assert ImageUploader.validate({file, nil}) == :ok
    end
  end

  describe "ImageUploader path generation" do
    setup do
      temp_dir = TempFileHelper.setup_temp_storage(%{})
      folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "path_test"})
      {:ok, temp_dir: temp_dir, folder: folder}
    end

    test "storage_dir/2 generates correct path from folder name", %{folder: folder} do
      # Create a mock file and scope
      file = %{file_name: "test.jpg"}
      scope = %{folder: folder}

      path = ImageUploader.storage_dir(:original, {file, scope})

      assert path == "uploads/images/path_test"
    end

    test "filename/2 for original version preserves basename", _context do
      file = %{file_name: "sunset.jpg"}

      filename = ImageUploader.filename(:original, {file, nil})

      assert filename == "sunset"
    end

    test "filename/2 for transformed versions adds version suffix", _context do
      file = %{file_name: "sunset.jpg"}

      thumb_filename = ImageUploader.filename(:thumb, {file, nil})
      web_md_filename = ImageUploader.filename(:web_md, {file, nil})
      web_lg_filename = ImageUploader.filename(:web_lg, {file, nil})

      assert thumb_filename == "sunset.thumb"
      assert web_md_filename == "sunset.web_md"
      assert web_lg_filename == "sunset.web_lg"
    end
  end
end
