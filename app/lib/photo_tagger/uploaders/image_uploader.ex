defmodule PhotoTagger.Uploaders.ImageUploader do
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original, :small, :thumb]
  @extensions ~w(.jpg .jpeg .gif .png)

  # Whitelist file extensions:
  def validate({file, _}) do
    file_extension = file.file_name |> Path.extname() |> String.downcase()

    case Enum.member?(@extensions, file_extension) do
      true -> :ok
      false -> {:error, "invalid file type"}
    end
  end

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}
  end

  def transform(:small, _) do
    {:convert, "-strip -define jpeg:extent=100KB -format jpg", :jpg}
  end

  # Override the persisted filenames:
  def filename(:original, {file, _scope}) do
    file.file_name
  end
  def filename(version, {file, _scope}) do
    "#{file.file_name}.#{version}"
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
