defmodule PhotoTagger.Uploaders.ImageUploader do
  use Waffle.Definition
  use Waffle.Ecto.Definition
  alias PhotoTagger.Repo

  require Logger

  @versions [:original, :small, :thumb, :web_lg, :web_md]
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

  def transform(:small, _) do
    {:convert, "-strip -define jpeg:extent=100KB -format jpg", :jpg}
  end

  def transform(:thumb, _) do
    # Resize image to a maximum of 300x300, cropping to a square aspect ratio.
    {:convert, "-strip -thumbnail 300x300^ -gravity center -extent 300x300 -format jpg", :jpg}
  end

  def transform(:web_md, _) do
    # Resizes to fit within 600x600, maintaining aspect ratio
    {:convert, "-strip -resize 600x600 -format jpg", :jpg}
  end

  def transform(:web_lg, _) do
    # Resizes to fit within 1400x1400, maintaining aspect ratio
    {:convert, "-strip -resize 1400x1400 -format jpg", :jpg}
  end

  # Override the persisted filenames:
  def filename(:original, {file, _scope}) do
    Path.basename(file.file_name, Path.extname(file.file_name))
  end

  def filename(version, {file, _scope}) do
    basename = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{basename}.#{version}"
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    folder_name =
      case scope do
        %{folder: %{name: name}} -> name
        %{folder_id: folder_id} -> Repo.get(PhotoTagger.Gallery.Folder, folder_id).name
      end

    "uploads/images/#{folder_name}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    "/images/logo.svg"
  end
end
