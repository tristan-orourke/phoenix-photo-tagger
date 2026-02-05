defmodule PhotoTagger.GalleryFixtures do
	@moduledoc """
	Test helpers for creating entities via the `PhotoTagger.Gallery` context.

	Provides two types of fixtures:
	- **Mocked fixtures** (default): Insert records directly into the database without
	  filesystem operations. Use for most tests.
	- **Real fixtures** (`*_with_files`): Create actual files and directories on disk.
	  Use for tests that verify filesystem operations.
	"""

	alias PhotoTagger.Gallery
	alias PhotoTagger.Gallery.{Folder, Photo, Tag, PhotoTag}
	alias PhotoTagger.Repo
	alias PhotoTagger.TempFileHelper

	# ============================================================================
	# Unique Value Generators
	# ============================================================================

	@doc """
	Generate a unique folder name.
	"""
	def unique_folder_name, do: "folder_#{System.unique_integer([:positive])}"

	@doc """
	Generate a unique photo name.
	"""
	def unique_photo_name, do: "photo_#{System.unique_integer([:positive])}.jpg"

	@doc """
	Generate a unique tag name.
	"""
	def unique_tag_name, do: "tag_#{System.unique_integer([:positive])}"

	# ============================================================================
	# Mocked Fixtures (No Filesystem Operations)
	# ============================================================================

	@doc """
	Creates a folder record directly in the database WITHOUT creating a filesystem directory.
	Use for most tests that don't need to verify filesystem operations.

	## Options

	- `:name` - Folder name (default: auto-generated unique name)
	- `:visibility_type` - Folder visibility: :private, :public, or :unlisted (default: :public)

	## Example

		folder = folder_fixture()
		folder = folder_fixture(%{name: "vacation", visibility_type: :private})
	"""
	def folder_fixture(attrs \\ %{}) do
		attrs =
			Enum.into(attrs, %{
				name: unique_folder_name(),
				visibility_type: :public
			})

		{:ok, folder} =
			%Folder{}
			|> Folder.changeset(attrs)
			|> Repo.insert()

		folder
	end

	@doc """
	Creates a photo record directly in the database WITHOUT uploading actual files.
	Inserts a minimal photo record with required fields populated.
	Use for most tests that don't need to verify filesystem operations.

	## Required Options

	- `:folder_id` - The folder ID this photo belongs to

	## Optional Options

	- `:name` - Photo name (default: auto-generated unique name)
	- `:description` - Photo description (default: nil)
	- `:notes` - Photo notes (default: nil)
	- `:group` - Photo group (default: nil)
	- `:is_public` - Whether photo is public (default: true)
	- `:manual_order` - Manual sort order (default: auto-assigned)
	- `:image_last_modified` - Image timestamp (default: now)

	## Example

		photo = photo_fixture(%{folder_id: folder.id})
		photo = photo_fixture(%{folder_id: folder.id, name: "sunset.jpg", is_public: false})
	"""
	def photo_fixture(attrs) do
		folder_id = Map.fetch!(attrs, :folder_id)

		# Get next manual order if not provided
		manual_order = Map.get_lazy(attrs, :manual_order, fn -> Gallery.get_next_manual_order(folder_id) end)

		name = Map.get(attrs, :name, unique_photo_name())

		# Create a fake Waffle image struct (mimics what Waffle stores)
		image = %{file_name: name, updated_at: DateTime.utc_now()}

		photo_attrs = %{
			name: name,
			folder_id: folder_id,
			image: image,
			description: Map.get(attrs, :description),
			notes: Map.get(attrs, :notes),
			group: Map.get(attrs, :group),
			is_public: Map.get(attrs, :is_public, true),
			manual_order: manual_order,
			image_last_modified: Map.get(attrs, :image_last_modified, DateTime.utc_now())
		}

		{:ok, photo} =
			%Photo{}
			|> Ecto.Changeset.cast(photo_attrs, [
				:name,
				:folder_id,
				:description,
				:notes,
				:group,
				:is_public,
				:manual_order,
				:image_last_modified
			])
			|> Ecto.Changeset.put_change(:image, image)
			|> Repo.insert()

		photo
	end

	@doc """
	Creates a tag with a unique name.
	Tags don't involve filesystem operations, so there's only one version.

	## Options

	- `:name` - Tag name (default: auto-generated unique name)

	## Example

		tag = tag_fixture()
		tag = tag_fixture(%{name: "landscape"})
	"""
	def tag_fixture(attrs \\ %{}) do
		name = Map.get(attrs, :name, unique_tag_name())

		{:ok, tag} =
			%Tag{}
			|> Tag.changeset(%{name: name})
			|> Repo.insert()

		tag
	end

	@doc """
	Creates a photo-tag association.

	## Options

	- `:photo` - The photo struct (required)
	- `:tag` - The tag struct (use this OR :tag_name)
	- `:tag_name` - Tag name string (will create tag if needed)

	## Example

		photo_tag_fixture(%{photo: photo, tag: tag})
		photo_tag_fixture(%{photo: photo, tag_name: "sunset"})
	"""
	def photo_tag_fixture(attrs) do
		photo = Map.fetch!(attrs, :photo)

		tag =
			case attrs do
				%{tag: tag} -> tag
				%{tag_name: name} -> tag_fixture(%{name: name})
			end

		{:ok, photo_tag} =
			%PhotoTag{}
			|> PhotoTag.changeset(%{photo_id: photo.id, tag_id: tag.id})
			|> Repo.insert()

		photo_tag
	end

	@doc """
	Creates a complete test scenario with mocked folder, photos, and tags (no filesystem).
	Useful for integration tests that don't need real files.

	## Options

	- `:photo_count` - Number of photos to create (default: 3)
	- `:tag_count` - Number of tags to create (default: 2)
	- `:folder_attrs` - Attributes for the folder (default: %{})

	## Returns

		%{
			folder: folder,
			photos: [photo1, photo2, ...],
			tags: [tag1, tag2, ...]
		}

	## Example

		scenario = gallery_scenario_fixture()
		scenario = gallery_scenario_fixture(%{photo_count: 5, tag_count: 3})
	"""
	def gallery_scenario_fixture(attrs \\ %{}) do
		photo_count = Map.get(attrs, :photo_count, 3)
		tag_count = Map.get(attrs, :tag_count, 2)
		folder_attrs = Map.get(attrs, :folder_attrs, %{})

		folder = folder_fixture(folder_attrs)

		photos =
			Enum.map(1..photo_count, fn _ ->
				photo_fixture(%{folder_id: folder.id})
			end)

		tags =
			Enum.map(1..tag_count, fn _ ->
				tag_fixture()
			end)

		%{
			folder: folder,
			photos: photos,
			tags: tags
		}
	end

	# ============================================================================
	# Real Fixtures (With Filesystem Operations)
	# ============================================================================

	@doc """
	Creates a folder with a unique name AND creates the actual filesystem directory.
	Use for tests that need to verify filesystem operations.

	## Required Options

	- `:temp_dir` - The temp directory from TempFileHelper.setup_temp_storage/1

	## Optional Options

	- `:name` - Folder name (default: auto-generated unique name)
	- `:visibility_type` - Folder visibility: :private, :public, or :unlisted (default: :public)

	## Example

		folder = folder_fixture_with_files(%{temp_dir: temp_dir})
		folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "vacation"})
	"""
	def folder_fixture_with_files(attrs) do
		_temp_dir = Map.fetch!(attrs, :temp_dir)

		name = Map.get(attrs, :name, unique_folder_name())
		visibility_type = Map.get(attrs, :visibility_type, "public")

		{:ok, %{create_folder_db: folder}} =
			Gallery.create_folder(%{"name" => name, "visibility_type" => visibility_type})

		folder
	end

	@doc """
	Creates a photo with a real uploaded image file.
	Use for tests that need to verify filesystem operations.

	## Required Options

	- `:temp_dir` - The temp directory from TempFileHelper.setup_temp_storage/1
	- `:folder_id` - The folder ID (folder must be created with folder_fixture_with_files)

	## Optional Options

	- `:name` - Photo filename (default: auto-generated unique name)
	- `:description` - Photo description (default: nil)
	- `:notes` - Photo notes (default: nil)
	- `:group` - Photo group (default: nil)
	- `:is_public` - Whether photo is public (default: true)
	- `:image_last_modified` - Image timestamp (default: now)

	## Example

		photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})
		photo = photo_fixture_with_files(%{
			temp_dir: temp_dir,
			folder_id: folder.id,
			name: "sunset.jpg"
		})
	"""
	def photo_fixture_with_files(attrs) do
		temp_dir = Map.fetch!(attrs, :temp_dir)
		folder_id = Map.fetch!(attrs, :folder_id)

		name = Map.get(attrs, :name, unique_photo_name())
		image_last_modified = Map.get(attrs, :image_last_modified, DateTime.utc_now())

		# Create a real test image file
		{:ok, image_path} = TempFileHelper.create_test_image(temp_dir, name)

		# Create Plug.Upload struct
		upload = TempFileHelper.create_upload_from_file(image_path, name)

		# Build attrs for Gallery.create_photo/1
		create_attrs = %{
			"folder_id" => folder_id,
			"image" => upload,
			"image_last_modified" => image_last_modified
		}

		# Add optional attrs
		create_attrs =
			create_attrs
			|> maybe_put("description", Map.get(attrs, :description))
			|> maybe_put("notes", Map.get(attrs, :notes))
			|> maybe_put("group", Map.get(attrs, :group))
			|> maybe_put("is_public", Map.get(attrs, :is_public))

		{:ok, photo} = Gallery.create_photo(create_attrs)

		photo
	end

	@doc """
	Creates a complete test scenario with real folder, photos, and tags on the filesystem.
	Use for integration tests that need real files.

	## Required Options

	- `:temp_dir` - The temp directory from TempFileHelper.setup_temp_storage/1

	## Optional Options

	- `:photo_count` - Number of photos to create (default: 3)
	- `:tag_count` - Number of tags to create (default: 2)
	- `:folder_attrs` - Additional attributes for the folder (default: %{})

	## Returns

		%{
			folder: folder,
			photos: [photo1, photo2, ...],
			tags: [tag1, tag2, ...]
		}

	## Example

		scenario = gallery_scenario_fixture_with_files(%{temp_dir: temp_dir})
		scenario = gallery_scenario_fixture_with_files(%{
			temp_dir: temp_dir,
			photo_count: 5,
			tag_count: 3
		})
	"""
	def gallery_scenario_fixture_with_files(attrs) do
		temp_dir = Map.fetch!(attrs, :temp_dir)
		photo_count = Map.get(attrs, :photo_count, 3)
		tag_count = Map.get(attrs, :tag_count, 2)
		folder_attrs = Map.get(attrs, :folder_attrs, %{})

		folder = folder_fixture_with_files(Map.put(folder_attrs, :temp_dir, temp_dir))

		photos =
			Enum.map(1..photo_count, fn _ ->
				photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})
			end)

		tags =
			Enum.map(1..tag_count, fn _ ->
				tag_fixture()
			end)

		%{
			folder: folder,
			photos: photos,
			tags: tags
		}
	end

	# ============================================================================
	# Private Helpers
	# ============================================================================

	defp maybe_put(map, _key, nil), do: map
	defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
