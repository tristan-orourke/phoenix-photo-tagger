defmodule PhotoTagger.TempFileHelper do
  @moduledoc """
  Helper module for managing temporary directories and test files.
  Used for tests that need to verify actual filesystem operations.
  """

  @doc """
  Creates a unique temp directory for a test and configures Waffle to use it.
  Returns the path to the temp directory.
  Automatically cleans up on test exit via on_exit callback.

  ## Example

  	setup do
  		temp_dir = TempFileHelper.setup_temp_storage(%{})
  		{:ok, temp_dir: temp_dir}
  	end
  """
  def setup_temp_storage(_context) do
    temp_dir =
      Path.join([
        System.tmp_dir!(),
        "photo_tagger_test_#{System.unique_integer([:positive])}"
      ])

    File.mkdir_p!(temp_dir)

    # Create the uploads/images directory that Gallery.create_folder expects
    uploads_dir = Path.join([temp_dir, "uploads", "images"])
    File.mkdir_p!(uploads_dir)

    # Configure Waffle to use this temp directory
    Application.put_env(:waffle, :storage_dir_prefix, temp_dir)

    # Register cleanup callback
    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!(temp_dir)
    end)

    temp_dir
  end

  @doc """
  Creates a test image file at the given path.
  Generates a simple 100x100 pixel JPEG using ImageMagick's convert command.
  Returns {:ok, full_path} or {:error, reason}.

  ## Example

  	{:ok, path} = TempFileHelper.create_test_image(temp_dir, "test.jpg")
  """
  def create_test_image(dir, filename) do
    full_path = Path.join(dir, filename)

    # Ensure directory exists
    File.mkdir_p!(dir)

    # Use ImageMagick to create a simple test image
    case System.cmd("convert", ["-size", "100x100", "xc:blue", full_path], stderr_to_stdout: true) do
      {_, 0} -> {:ok, full_path}
      {error, _} -> {:error, error}
    end
  end

  @doc """
  Creates a Plug.Upload struct from a file path.
  This mimics what Phoenix receives from file uploads.

  ## Example

  	upload = TempFileHelper.create_upload_from_file("/tmp/test.jpg", "photo.jpg")
  """
  def create_upload_from_file(file_path, original_filename) do
    content_type =
      case Path.extname(original_filename) |> String.downcase() do
        ".jpg" -> "image/jpeg"
        ".jpeg" -> "image/jpeg"
        ".png" -> "image/png"
        ".gif" -> "image/gif"
        _ -> "application/octet-stream"
      end

    %Plug.Upload{
      path: file_path,
      filename: original_filename,
      content_type: content_type
    }
  end

  @doc """
  Verifies that a file exists at the expected Waffle storage path.
  Returns true/false.

  ## Example

  	assert TempFileHelper.image_exists?(photo, :original)
  	assert TempFileHelper.image_exists?(photo, :thumb)
  """
  def image_exists?(photo, version) do
    path = get_image_path(photo, version)
    File.exists?(path)
  end

  @doc """
  Returns the full path to an uploaded image version.

  ## Example

  	path = TempFileHelper.get_image_path(photo, :original)
  """
  def get_image_path(photo, version) do
    photo = PhotoTagger.Repo.preload(photo, :folder)
    storage_dir_prefix = Application.get_env(:waffle, :storage_dir_prefix)

    ext =
      case version do
        :original -> Path.extname(photo.image.file_name)
        _ -> ".webp"
      end

    filename = PhotoTagger.Uploaders.ImageUploader.filename(version, {photo.image, photo})

    Path.join([
      storage_dir_prefix,
      "uploads/images/#{photo.folder.name}",
      filename <> ext
    ])
  end

  @doc """
  Returns the full path to a folder's directory.

  ## Example

  	path = TempFileHelper.get_folder_path(folder)
  """
  def get_folder_path(folder) do
    storage_dir_prefix = Application.get_env(:waffle, :storage_dir_prefix)

    Path.join([
      storage_dir_prefix,
      "uploads/images/#{folder.name}"
    ])
  end

  @doc """
  Verifies that a folder's directory exists on the filesystem.
  Returns true/false.

  ## Example

  	assert TempFileHelper.folder_exists?(folder)
  """
  def folder_exists?(folder) do
    path = get_folder_path(folder)
    File.dir?(path)
  end
end
