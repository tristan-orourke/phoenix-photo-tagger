defmodule Mix.Tasks.ImportPhotosFromDisk do
  @moduledoc """
  Reconstructs photo and folder database records from image files on disk.

  Scans `priv/static/uploads/images/` for original image files (excludes
  .thumb.webp, .web_md.webp, .web_lg.webp variants) and creates corresponding
  folder and photo records.

  Cannot recover tags, descriptions, notes, groups, and visibility settings.

  Usage:
      mix import_photos_from_disk
  """

  use Mix.Task
  import Ecto.Changeset

  alias PhotoTagger.Gallery.{Folder, Photo}
  alias PhotoTagger.Gallery
  alias PhotoTagger.Repo

  @uploads_root "priv/static/uploads/images"
  @variant_suffixes [".thumb.webp", ".web_md.webp", ".web_lg.webp"]

  def run(_args) do
    Mix.Task.run("app.start")

    uploads_path = Path.join(Application.app_dir(:photo_tagger, "priv"), "../#{@uploads_root}")
      |> Path.expand()

    # Also try the dev path directly
    uploads_path =
      if File.dir?(uploads_path) do
        uploads_path
      else
        Path.join(File.cwd!(), @uploads_root)
      end

    unless File.dir?(uploads_path) do
      Mix.shell().error("Uploads directory not found: #{uploads_path}")
      exit(:error)
    end

    Mix.shell().info("Scanning #{uploads_path} ...")

    folder_dirs =
      File.ls!(uploads_path)
      |> Enum.filter(fn entry -> File.dir?(Path.join(uploads_path, entry)) end)
      |> Enum.sort()

    Mix.shell().info("Found #{length(folder_dirs)} folder(s): #{Enum.join(folder_dirs, ", ")}")

    start_order = Gallery.get_next_manual_order() - 1
    order_counter = :counters.new(1, [:atomics])
    :counters.put(order_counter, 1, start_order)

    Enum.each(folder_dirs, fn folder_name ->
      case find_or_create_folder(folder_name) do
        {:ok, folder} ->
          folder_path = Path.join(uploads_path, folder_name)

          original_files =
            File.ls!(folder_path)
            |> Enum.filter(&is_original_file?/1)
            |> Enum.sort()

          Mix.shell().info("  #{folder_name}: #{length(original_files)} original file(s)")

          Enum.each(original_files, fn filename ->
            file_path = Path.join(folder_path, filename)
            :counters.add(order_counter, 1, 1)
            current_order = :counters.get(order_counter, 1)
            import_photo(folder, filename, file_path, current_order)
          end)

        {:error, _reason} ->
          Mix.shell().error("  Skipping folder #{folder_name} due to creation failure.")
      end
    end)

    total = :counters.get(order_counter, 1) - start_order
    Mix.shell().info("\nImported #{total} photo(s) total.")
  end

  defp is_original_file?(filename) do
    lower = String.downcase(filename)

    has_valid_ext =
      String.ends_with?(lower, ".jpg") or
        String.ends_with?(lower, ".jpeg") or
        String.ends_with?(lower, ".png") or
        String.ends_with?(lower, ".gif")

    not_variant = not Enum.any?(@variant_suffixes, &String.ends_with?(lower, &1))

    has_valid_ext and not_variant
  end

  defp find_or_create_folder(name) do
    case Repo.get_by(Folder, name: name) do
      nil ->
        case %Folder{}
             |> Folder.changeset(%{name: name, visibility_type: :private})
             |> Repo.insert() do
          {:ok, folder} ->
            Mix.shell().info("  Created folder: #{name}")
            {:ok, folder}

          {:error, changeset} ->
            errors = format_changeset_errors(changeset)
            Mix.shell().error("  Failed to create folder #{name}: #{errors}")
            {:error, changeset}
        end

      folder ->
        {:ok, folder}
    end
  end

  defp import_photo(folder, filename, file_path, manual_order) do
    existing = Repo.get_by(Photo, name: filename, folder_id: folder.id)

    if existing do
      Mix.shell().info("    Skipping #{filename} (already exists)")
    else
      stat = File.stat!(file_path, time: :posix)

      image_last_modified =
        DateTime.from_unix!(stat.mtime)

      image = %{file_name: filename, updated_at: DateTime.utc_now()}

      result =
        %Photo{}
        |> cast(
          %{
            name: filename,
            folder_id: folder.id,
            is_public: true,
            manual_order: manual_order,
            image_last_modified: image_last_modified
          },
          [:name, :folder_id, :is_public, :manual_order, :image_last_modified]
        )
        |> put_change(:image, image)
        |> Repo.insert()

      case result do
        {:ok, _photo} ->
          Mix.shell().info("    Imported #{filename} (order: #{manual_order})")

        {:error, changeset} ->
          errors = format_changeset_errors(changeset)
          Mix.shell().error("    Failed to import #{filename}: #{errors}")
      end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
