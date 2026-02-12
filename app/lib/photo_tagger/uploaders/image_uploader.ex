defmodule PhotoTagger.Uploaders.ImageUploader do
  use Waffle.Definition
  use Waffle.Ecto.Definition
  alias PhotoTagger.Repo

  require Logger

  @versions [:original, :thumb, :web_md, :web_lg]
  @extensions ~w(.jpg .jpeg .gif .png)

  def valid_extensions, do: @extensions
  def versions, do: @versions

  # Whitelist file extensions:
  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(@extensions, file_extension) do
      true -> :ok
      false -> {:error, "invalid file type"}
    end
  end

  def transform(:thumb, _) do
    # Resize image to a maximum of 300x300, cropping to a square aspect ratio.
    {:convert, "-strip -thumbnail 300x300^ -gravity center -extent 300x300 -format webp", :webp}
  end

  def transform(:web_md, _) do
    # Resizes to fit within 600x600, maintaining aspect ratio
    {:convert, "-strip -resize 600x600 -format webp", :webp}
  end

  def transform(:web_lg, _) do
    # Resizes to fit within 1400x1400, maintaining aspect ratio
    {:convert, "-strip -resize 1400x1400 -format webp", :webp}
  end

  # Override the persisted filenames:
  def filename(:original, {file, _scope}) do
    Path.basename(file.file_name, Path.extname(file.file_name))
  end

  def filename(version, {file, _scope}) do
    basename = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{basename}.#{version}"
  end

  @doc """
  Returns the storage directory for a photo's image files.

  For cross-listed photos, resolves to the original photo's folder
  since cross-listings don't have their own files on disk.
  """
  def storage_dir(_version, {_file, scope}) do
    folder_name = resolve_storage_folder_name(scope)
    "uploads/images/#{folder_name}"
  end

  # Cross-listed photo with original's folder already preloaded
  defp resolve_storage_folder_name(%{original_photo: %{folder: %{name: name}}})
       when is_binary(name),
       do: name

  # Cross-listed photo without preloaded original - fall back to DB lookup
  defp resolve_storage_folder_name(%{original_photo_id: original_id})
       when not is_nil(original_id) do
    PhotoTagger.Gallery.Photo
    |> Repo.get!(original_id)
    |> Repo.preload(:folder)
    |> Map.get(:folder)
    |> Map.get(:name)
  end

  # Regular photo with folder preloaded
  defp resolve_storage_folder_name(%{folder: %{name: name}}), do: name

  # Regular photo with only folder_id
  defp resolve_storage_folder_name(%{folder_id: folder_id}) do
    Repo.get!(PhotoTagger.Gallery.Folder, folder_id).name
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    "/images/logo.svg"
  end
end
