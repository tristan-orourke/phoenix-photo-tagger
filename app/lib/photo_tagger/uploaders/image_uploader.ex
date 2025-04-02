defmodule PhotoTagger.Uploaders.ImageUploader do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  require Logger

  @versions [:original, :small, :sq90, :sq200, :sq360, :sq600]
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

  def transform(:sq90, _) do
    {:convert, "-strip -resize 90x90^ -gravity center -crop 90x90+0+0 +repage", :jpg}
  end
  def transform(:sq200, _) do
    {:convert, "-strip -resize 200x200^ -gravity center -crop 200x200+0+0 +repage", :jpg}
  end
  def transform(:sq360, _) do
    {:convert, "-strip -resize 360x360^ -gravity center -crop 360x360+0+0 +repage", :jpg}
  end
  def transform(:sq600, _) do
    {:convert, "-strip -resize 600x600^ -gravity center -crop 600x600+0+0 +repage", :jpg}
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
    "uploads/images/#{scope.folder}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    "/images/logo.svg"
  end
end
