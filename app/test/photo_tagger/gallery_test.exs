defmodule PhotoTagger.GalleryTest do
	@moduledoc """
	Tests for the PhotoTagger.Gallery context.

	Most tests use mocked fixtures (no filesystem operations).
	Tests that verify filesystem behavior use real fixtures with temp directories.
	"""

	use PhotoTagger.DataCase

	alias PhotoTagger.Gallery
	alias PhotoTagger.Gallery.Photo

	import PhotoTagger.GalleryFixtures

	describe "photos (mocked fixtures)" do
		setup do
			folder = folder_fixture()
			{:ok, folder: folder}
		end

		test "list_photos/0 returns all public photos", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			[result] = Gallery.list_photos()
			assert result.id == photo.id
		end

		test "list_photos/1 with include_private: true returns all photos", %{folder: folder} do
			public_photo = photo_fixture(%{folder_id: folder.id, is_public: true})
			private_photo = photo_fixture(%{folder_id: folder.id, is_public: false})

			# Without flag, only public photos
			public_results = Gallery.list_photos()
			assert length(public_results) == 1
			assert hd(public_results).id == public_photo.id

			# With flag, all photos
			all_results = Gallery.list_photos(include_private: true)
			assert length(all_results) == 2
			result_ids = Enum.map(all_results, & &1.id)
			assert public_photo.id in result_ids
			assert private_photo.id in result_ids
		end

		test "get_photo!/1 returns the photo with given id", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			result = Gallery.get_photo!(photo.id)
			assert result.id == photo.id
		end

		test "get_photo!/1 raises when photo is private and include_private is false", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id, is_public: false})
			assert_raise Ecto.NoResultsError, fn -> Gallery.get_photo!(photo.id) end
		end

		test "get_photo!/1 returns private photo with include_private: true", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id, is_public: false})
			result = Gallery.get_photo!(photo.id, include_private: true)
			assert result.id == photo.id
		end

		test "update_photo/2 with valid data updates the photo", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			update_attrs = %{description: "updated description"}

			# update_photo returns {:ok, %{photo: photo, ...}} from Multi
			assert {:ok, %{photo: updated}} = Gallery.update_photo(photo, update_attrs)
			assert updated.description == "updated description"
		end

		test "update_photo/2 returns ok even with empty attrs", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			# The update changeset doesn't have required validations,
			# so even empty attrs will succeed (no changes made)
			assert {:ok, %{photo: _updated}} = Gallery.update_photo(photo, %{})
		end

		test "new_photo_changeset/1 returns a photo changeset", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			assert %Ecto.Changeset{} = Gallery.new_photo_changeset(photo)
		end

		test "create_photo/1 auto-assigns manual_order", %{folder: folder} do
			# Create photos using mocked fixture to check manual_order assignment
			photo1 = photo_fixture(%{folder_id: folder.id})
			photo2 = photo_fixture(%{folder_id: folder.id})
			photo3 = photo_fixture(%{folder_id: folder.id})

			assert photo1.manual_order == 1
			assert photo2.manual_order == 2
			assert photo3.manual_order == 3
		end
	end

	describe "photos (real files)" do
		alias PhotoTagger.TempFileHelper

		setup do
			temp_dir = TempFileHelper.setup_temp_storage(%{})
			folder = folder_fixture_with_files(%{temp_dir: temp_dir})
			{:ok, temp_dir: temp_dir, folder: folder}
		end

		test "create_photo/1 with valid data creates a photo", %{temp_dir: temp_dir, folder: folder} do
			{:ok, image_path} = TempFileHelper.create_test_image(temp_dir, "test_photo.jpg")
			upload = TempFileHelper.create_upload_from_file(image_path, "test_photo.jpg")

			valid_attrs = %{
				"folder_id" => folder.id,
				"image" => upload,
				"image_last_modified" => DateTime.utc_now()
			}

			assert {:ok, %Photo{} = photo} = Gallery.create_photo(valid_attrs)
			assert photo.name == "test_photo.jpg"
			assert photo.folder_id == folder.id
		end

		test "create_photo/1 with missing image raises error", %{temp_dir: _temp_dir, folder: folder} do
			# Missing image field causes KeyError since create_photo expects attrs["image"].filename
			attrs = %{
				"folder_id" => folder.id,
				"image_last_modified" => DateTime.utc_now()
			}
			assert_raise KeyError, fn -> Gallery.create_photo(attrs) end
		end

		test "delete_photo/1 deletes the photo and files", %{temp_dir: temp_dir, folder: folder} do
			photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

			# Verify files exist before deletion
			assert TempFileHelper.image_exists?(photo, :original)

			assert {:ok, %Photo{}} = Gallery.delete_photo(photo)

			# Photo should be gone from database
			assert_raise Ecto.NoResultsError, fn ->
				Gallery.get_photo!(photo.id, include_private: true)
			end

			# Files should be gone too
			refute TempFileHelper.image_exists?(photo, :original)
		end
	end

	describe "tags" do
		setup do
			folder = folder_fixture()
			{:ok, folder: folder}
		end

		test "list_tags/0 returns all tags sorted by name" do
			_tag_c = tag_fixture(%{name: "c_tag"})
			_tag_a = tag_fixture(%{name: "a_tag"})
			_tag_b = tag_fixture(%{name: "b_tag"})

			tags = Gallery.list_tags()
			tag_names = Enum.map(tags, & &1.name)

			assert tag_names == ["a_tag", "b_tag", "c_tag"]
			assert length(tags) == 3
		end

		test "add_tag_to_photo/2 creates association", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			tag = tag_fixture(%{name: "landscape"})

			assert {:ok, _photo_tag} = Gallery.add_tag_to_photo(photo, "landscape")

			photo_with_tags = Gallery.get_photo!(photo.id) |> Repo.preload(:tags)
			assert length(photo_with_tags.tags) == 1
			assert hd(photo_with_tags.tags).id == tag.id
		end

		test "add_tag_to_photo/2 creates tag if it doesn't exist", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})

			assert {:ok, _photo_tag} = Gallery.add_tag_to_photo(photo, "new_tag")

			# Tag should have been created
			tags = Gallery.list_tags()
			assert Enum.any?(tags, &(&1.name == "new_tag"))
		end

		test "add_tag_to_photo/2 is idempotent", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})

			# Add same tag twice
			assert {:ok, _} = Gallery.add_tag_to_photo(photo, "sunset")
			assert {:ok, _} = Gallery.add_tag_to_photo(photo, "sunset")

			# Should only have one association
			photo_with_tags = Gallery.get_photo!(photo.id) |> Repo.preload(:tags)
			assert length(photo_with_tags.tags) == 1
		end

		test "remove_tag_from_photo/2 removes association", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			Gallery.add_tag_to_photo(photo, "to_remove")

			# Verify tag is added
			photo_with_tags = Gallery.get_photo!(photo.id) |> Repo.preload(:tags)
			assert length(photo_with_tags.tags) == 1

			# Remove the tag
			assert {:ok, _} = Gallery.remove_tag_from_photo(photo, "to_remove")

			# Verify tag is gone from photo
			photo_after = Gallery.get_photo!(photo.id) |> Repo.preload(:tags)
			assert length(photo_after.tags) == 0
		end

		test "remove_tag_from_photo/2 returns ok when tag not on photo", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})

			# Try to remove a tag that isn't on the photo
			assert {:ok, nil} = Gallery.remove_tag_from_photo(photo, "nonexistent")
		end

		test "tag names are case insensitive", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})

			# Add tag with uppercase
			Gallery.add_tag_to_photo(photo, "Sunset")

			# Try to add same tag with different case
			Gallery.add_tag_to_photo(photo, "sunset")

			# Should only have one tag
			photo_with_tags = Gallery.get_photo!(photo.id) |> Repo.preload(:tags)
			assert length(photo_with_tags.tags) == 1
		end
	end

	describe "photo listing and filtering" do
		setup do
			folder = folder_fixture()
			{:ok, folder: folder}
		end

		test "list_photos/1 with sort: :date orders by inserted_at desc then name asc", %{folder: folder} do
			# The sort order is by inserted_at desc, then name asc
			# Since all photos are created in quick succession with same inserted_at,
			# they'll be sorted by name ascending
			_photo1 = photo_fixture(%{folder_id: folder.id, name: "c_photo.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, name: "a_photo.jpg"})
			_photo3 = photo_fixture(%{folder_id: folder.id, name: "b_photo.jpg"})

			# With same inserted_at, secondary sort is by name asc
			photos = Gallery.list_photos(sort: :date, include_private: true)
			photo_names = Enum.map(photos, & &1.name)

			assert photo_names == ["a_photo.jpg", "b_photo.jpg", "c_photo.jpg"]
		end

		test "list_photos/1 with sort: :manual orders by manual_order asc", %{folder: folder} do
			_photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "third.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "first.jpg"})
			_photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "second.jpg"})

			photos = Gallery.list_photos(sort: :manual, include_private: true)
			photo_names = Enum.map(photos, & &1.name)

			assert photo_names == ["first.jpg", "second.jpg", "third.jpg"]
		end

		test "list_photos/1 with sort: :manual and sort_direction: :asc orders by manual_order asc", %{
			folder: folder
		} do
			_photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "third.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "first.jpg"})
			_photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "second.jpg"})

			photos = Gallery.list_photos(sort: :manual, sort_direction: :asc, include_private: true)
			photo_names = Enum.map(photos, & &1.name)

			assert photo_names == ["first.jpg", "second.jpg", "third.jpg"]
		end

		test "list_photos/1 with sort: :manual and sort_direction: :desc orders by manual_order desc", %{
			folder: folder
		} do
			_photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "third.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "first.jpg"})
			_photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "second.jpg"})

			photos = Gallery.list_photos(sort: :manual, sort_direction: :desc, include_private: true)
			photo_names = Enum.map(photos, & &1.name)

			assert photo_names == ["third.jpg", "second.jpg", "first.jpg"]
		end

		test "list_photos/1 with sort_direction: :asc orders photos ascending by date", %{folder: folder} do
			# Create photos with different timestamps by manually setting inserted_at
			import Ecto.Query
			alias PhotoTagger.Repo

			photo1 = photo_fixture(%{folder_id: folder.id, name: "oldest.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, name: "middle.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, name: "newest.jpg"})

			# Update inserted_at timestamps to ensure different values
			Repo.update_all(
				from(p in Photo, where: p.id == ^photo1.id),
				set: [inserted_at: ~N[2024-01-01 10:00:00]]
			)

			Repo.update_all(
				from(p in Photo, where: p.id == ^photo2.id),
				set: [inserted_at: ~N[2024-01-02 10:00:00]]
			)

			Repo.update_all(
				from(p in Photo, where: p.id == ^photo3.id),
				set: [inserted_at: ~N[2024-01-03 10:00:00]]
			)

			# Test ascending order (oldest first)
			photos = Gallery.list_photos(sort: :date, sort_direction: :asc, include_private: true)
			photo_names = Enum.map(photos, & &1.name)
			assert photo_names == ["oldest.jpg", "middle.jpg", "newest.jpg"]
		end

		test "list_photos/1 with sort_direction: :desc orders photos descending by date (default)", %{
			folder: folder
		} do
			# Create photos with different timestamps
			import Ecto.Query
			alias PhotoTagger.Repo

			photo1 = photo_fixture(%{folder_id: folder.id, name: "oldest.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, name: "middle.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, name: "newest.jpg"})

			# Update inserted_at timestamps
			Repo.update_all(
				from(p in Photo, where: p.id == ^photo1.id),
				set: [inserted_at: ~N[2024-01-01 10:00:00]]
			)

			Repo.update_all(
				from(p in Photo, where: p.id == ^photo2.id),
				set: [inserted_at: ~N[2024-01-02 10:00:00]]
			)

			Repo.update_all(
				from(p in Photo, where: p.id == ^photo3.id),
				set: [inserted_at: ~N[2024-01-03 10:00:00]]
			)

			# Test descending order (newest first) - this is the default
			photos = Gallery.list_photos(sort: :date, sort_direction: :desc, include_private: true)
			photo_names = Enum.map(photos, & &1.name)
			assert photo_names == ["newest.jpg", "middle.jpg", "oldest.jpg"]
		end

		test "list_photos_by_folder/1 returns only photos in folder", %{folder: folder} do
			folder2 = folder_fixture(%{name: "other_folder"})

			photo1 = photo_fixture(%{folder_id: folder.id, name: "in_folder.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder2.id, name: "other_folder.jpg"})

			photos = Gallery.list_photos_by_folder(folder.name, include_private: true)

			assert length(photos) == 1
			assert hd(photos).id == photo1.id
		end

		test "list_photos_by_all_tags/1 returns photos with all specified tags (AND logic)", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id, name: "has_both.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, name: "has_one.jpg"})
			_photo3 = photo_fixture(%{folder_id: folder.id, name: "has_none.jpg"})

			Gallery.add_tag_to_photo(photo1, "landscape")
			Gallery.add_tag_to_photo(photo1, "sunset")
			Gallery.add_tag_to_photo(photo2, "landscape")

			# Query for photos with BOTH tags
			photos = Gallery.list_photos_by_all_tags(["landscape", "sunset"], include_private: true)

			assert length(photos) == 1
			assert hd(photos).id == photo1.id
		end

		test "list_photos_by_all_tags/1 with empty list returns all photos", %{folder: folder} do
			_photo1 = photo_fixture(%{folder_id: folder.id})
			_photo2 = photo_fixture(%{folder_id: folder.id})

			photos = Gallery.list_photos_by_all_tags([], include_private: true)
			assert length(photos) == 2
		end

		test "list_photos_by_tags/1 with include filters photos with all included tags", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id, name: "tagged.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, name: "untagged.jpg"})

			Gallery.add_tag_to_photo(photo1, "nature")

			photos = Gallery.list_photos_by_tags(%{include: ["nature"], exclude: []}, include_private: true)

			assert length(photos) == 1
			assert hd(photos).id == photo1.id
		end

		test "list_photos_by_tags/1 with include nil returns untagged photos", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id, name: "tagged.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, name: "untagged.jpg"})

			Gallery.add_tag_to_photo(photo1, "nature")

			photos = Gallery.list_photos_by_tags(%{include: nil, exclude: []}, include_private: true)

			assert length(photos) == 1
			assert hd(photos).id == photo2.id
		end

		test "list_photos_by_tags/1 with exclude filters out photos with excluded tags", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id, name: "excluded.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, name: "included.jpg"})

			Gallery.add_tag_to_photo(photo1, "rejected")

			photos = Gallery.list_photos_by_tags(%{include: [], exclude: ["rejected"]}, include_private: true)

			assert length(photos) == 1
			assert hd(photos).id == photo2.id
		end

		test "list_photos_by_tags/1 with both include and exclude", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id, name: "nature_sunset.jpg"})
			photo2 = photo_fixture(%{folder_id: folder.id, name: "nature_only.jpg"})
			_photo3 = photo_fixture(%{folder_id: folder.id, name: "neither.jpg"})

			Gallery.add_tag_to_photo(photo1, "nature")
			Gallery.add_tag_to_photo(photo1, "sunset")
			Gallery.add_tag_to_photo(photo2, "nature")

			# Include nature, exclude sunset
			photos = Gallery.list_photos_by_tags(
				%{include: ["nature"], exclude: ["sunset"]},
				include_private: true
			)

			assert length(photos) == 1
			assert hd(photos).id == photo2.id
		end

		test "list_photos_by_folder_and_tags/2 combines folder and tag filtering", %{folder: folder} do
			folder2 = folder_fixture(%{name: "other_folder"})

			photo1 = photo_fixture(%{folder_id: folder.id, name: "in_folder_tagged.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, name: "in_folder_untagged.jpg"})
			photo3 = photo_fixture(%{folder_id: folder2.id, name: "other_folder_tagged.jpg"})

			Gallery.add_tag_to_photo(photo1, "nature")
			Gallery.add_tag_to_photo(photo3, "nature")

			photos = Gallery.list_photos_by_folder_and_tags(
				folder.name,
				%{include: ["nature"], exclude: []},
				include_private: true
			)

			assert length(photos) == 1
			assert hd(photos).id == photo1.id
		end

		test "list_tags_by_folder/1 returns only tags used in that folder", %{folder: folder} do
			folder2 = folder_fixture(%{name: "other_folder"})

			photo1 = photo_fixture(%{folder_id: folder.id})
			photo2 = photo_fixture(%{folder_id: folder2.id})

			Gallery.add_tag_to_photo(photo1, "folder1_tag")
			Gallery.add_tag_to_photo(photo2, "folder2_tag")

			tags = Gallery.list_tags_by_folder(folder.name)
			tag_names = Enum.map(tags, & &1.name)

			assert tag_names == ["folder1_tag"]
		end

		test "list_tags_by_photos/1 returns tags from specified photos", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id})
			photo2 = photo_fixture(%{folder_id: folder.id})
			photo3 = photo_fixture(%{folder_id: folder.id})

			Gallery.add_tag_to_photo(photo1, "tag_a")
			Gallery.add_tag_to_photo(photo1, "tag_b")
			Gallery.add_tag_to_photo(photo2, "tag_b")
			Gallery.add_tag_to_photo(photo3, "tag_c")

			tags = Gallery.list_tags_by_photos([photo1.id, photo2.id])
			tag_names = Enum.map(tags, & &1.name)

			# Should return tag_a and tag_b (sorted), not tag_c
			assert tag_names == ["tag_a", "tag_b"]
		end

		test "list_folders_include_tags/0 returns folders with their tag arrays", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			Gallery.add_tag_to_photo(photo, "landscape")
			Gallery.add_tag_to_photo(photo, "nature")

			folders = Gallery.list_folders_include_tags(include_private: true)
			# Returns %{name: name, tags: [tag_names]}
			folder_with_tags = Enum.find(folders, &(&1.name == folder.name))

			assert folder_with_tags != nil
			# The folder should have tags aggregated
			assert is_list(folder_with_tags.tags)
			tag_names = folder_with_tags.tags |> Enum.sort()
			assert "landscape" in tag_names
			assert "nature" in tag_names
		end

		test "get_photos_by_ids/1 returns photos matching the ids", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id})
			photo2 = photo_fixture(%{folder_id: folder.id})
			_photo3 = photo_fixture(%{folder_id: folder.id})

			photos = Gallery.get_photos_by_ids([photo1.id, photo2.id], include_private: true)
			photo_ids = Enum.map(photos, & &1.id) |> Enum.sort()

			assert photo_ids == Enum.sort([photo1.id, photo2.id])
		end

		test "get_next_manual_order/1 returns 1 for empty folder", %{folder: _folder} do
			empty_folder = folder_fixture(%{name: "empty_folder"})
			assert Gallery.get_next_manual_order(empty_folder.id) == 1
		end

		test "get_next_manual_order/1 returns max + 1 for folder with photos", %{folder: folder} do
			_photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 5})
			_photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 3})

			assert Gallery.get_next_manual_order(folder.id) == 6
		end
	end

	describe "related tags" do
		setup do
			folder = folder_fixture()
			{:ok, folder: folder}
		end

		test "get_related_tags/1 returns tags from photos with overlapping tags", %{folder: folder} do
			photo1 = photo_fixture(%{folder_id: folder.id})
			photo2 = photo_fixture(%{folder_id: folder.id})
			photo3 = photo_fixture(%{folder_id: folder.id})

			# photo1 has: landscape, sunset
			# photo2 has: landscape, beach
			# photo3 has: portrait (no overlap)
			Gallery.add_tag_to_photo(photo1, "landscape")
			Gallery.add_tag_to_photo(photo1, "sunset")
			Gallery.add_tag_to_photo(photo2, "landscape")
			Gallery.add_tag_to_photo(photo2, "beach")
			Gallery.add_tag_to_photo(photo3, "portrait")

			# Get related tags for photo1
			# Should find photo2 (shares "landscape") and return "beach"
			# Should NOT return "sunset" (from photo1 itself) or "portrait" (no overlap)
			related = Gallery.get_related_tags(photo1)
			related_names = Enum.map(related, & &1.name)

			assert "beach" in related_names
			refute "sunset" in related_names
			refute "portrait" in related_names
			refute "landscape" in related_names
		end
	end

	describe "additional utility functions" do
		setup do
			folder = folder_fixture()
			{:ok, folder: folder}
		end

		test "update_photo_changeset/2 returns a changeset", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})
			changeset = Gallery.update_photo_changeset(photo, %{description: "new desc"})

			assert %Ecto.Changeset{} = changeset
			assert changeset.valid?
		end

		test "delete_orphan_tags/0 removes tags with no photos", %{folder: folder} do
			photo = photo_fixture(%{folder_id: folder.id})

			# Add tag to photo
			Gallery.add_tag_to_photo(photo, "orphan_candidate")

			# Verify tag exists
			assert Enum.any?(Gallery.list_tags(), &(&1.name == "orphan_candidate"))

			# Remove tag from photo
			Gallery.remove_tag_from_photo(photo, "orphan_candidate")

			# Tag should still exist (orphaned but not deleted yet)
			assert Enum.any?(Gallery.list_tags(), &(&1.name == "orphan_candidate"))

			# Delete orphan tags
			Gallery.delete_orphan_tags()

			# Tag should now be gone
			refute Enum.any?(Gallery.list_tags(), &(&1.name == "orphan_candidate"))
		end
	end

	describe "folders (mocked fixtures)" do
		test "list_folders/0 returns all public folders sorted by name" do
			_folder_c = folder_fixture(%{name: "c_folder", is_public: true})
			_folder_a = folder_fixture(%{name: "a_folder", is_public: true})
			_folder_private = folder_fixture(%{name: "b_private", is_public: false})

			folders = Gallery.list_folders()
			folder_names = Enum.map(folders, & &1.name)

			# Should only include public folders, sorted
			assert folder_names == ["a_folder", "c_folder"]
		end

		test "list_folders/1 with include_private: true returns all folders" do
			folder_fixture(%{name: "public_folder", is_public: true})
			folder_fixture(%{name: "private_folder", is_public: false})

			all_folders = Gallery.list_folders(include_private: true)
			assert length(all_folders) == 2
		end

		test "get_folder_by_name!/1 returns folder" do
			folder = folder_fixture(%{name: "test_folder"})
			result = Gallery.get_folder_by_name!("test_folder")
			assert result.id == folder.id
		end
	end

	describe "folders (real files)" do
		alias PhotoTagger.TempFileHelper

		setup do
			temp_dir = TempFileHelper.setup_temp_storage(%{})
			{:ok, temp_dir: temp_dir}
		end

		test "create_folder/1 creates folder in database and filesystem", %{temp_dir: _temp_dir} do
			{:ok, %{create_folder_db: folder}} =
				Gallery.create_folder(%{"name" => "new_folder", "is_public" => true})

			assert folder.name == "new_folder"
			assert TempFileHelper.folder_exists?(folder)
		end

		test "update_folder/2 updates folder attributes", %{temp_dir: temp_dir} do
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, is_public: false})

			assert {:ok, %{update_folder_db: updated}} =
				Gallery.update_folder(folder, %{"name" => folder.name, "is_public" => true})

			assert updated.is_public == true
		end

		test "update_folder/2 renames directory when name changes", %{temp_dir: temp_dir} do
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "old_name"})

			# Verify old directory exists
			assert TempFileHelper.folder_exists?(folder)
			old_path = TempFileHelper.get_folder_path(folder)

			assert {:ok, %{update_folder_db: updated}} =
				Gallery.update_folder(folder, %{"name" => "new_name", "is_public" => folder.is_public})

			# Old path should be gone, new path should exist
			refute File.dir?(old_path)
			assert TempFileHelper.folder_exists?(updated)
		end

		test "update_folder/2 moves photo files when name changes", %{temp_dir: temp_dir} do
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "original_folder"})
			photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

			# Verify photo file exists in original location
			assert TempFileHelper.image_exists?(photo, :original)
			old_image_path = TempFileHelper.get_image_path(photo, :original)

			# Rename folder
			assert {:ok, %{update_folder_db: _updated}} =
				Gallery.update_folder(folder, %{"name" => "renamed_folder", "is_public" => folder.is_public})

			# Old image path should be gone
			refute File.exists?(old_image_path)

			# Reload photo and verify it still exists at new location
			updated_photo = Gallery.get_photo!(photo.id, include_private: true)
			assert TempFileHelper.image_exists?(updated_photo, :original)
		end

		test "delete_folder/1 deletes folder, photos, and filesystem directory", %{temp_dir: temp_dir} do
			folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "to_delete"})
			photo = photo_fixture_with_files(%{temp_dir: temp_dir, folder_id: folder.id})

			# Verify folder and photo exist
			assert TempFileHelper.folder_exists?(folder)
			assert TempFileHelper.image_exists?(photo, :original)

			# Delete folder (takes folder name, not struct)
			assert {:ok, _} = Gallery.delete_folder(folder.name)

			# Folder and contents should be gone
			refute TempFileHelper.folder_exists?(folder)
			assert_raise Ecto.NoResultsError, fn ->
				Gallery.get_photo!(photo.id, include_private: true)
			end
		end
	end

	describe "photo file operations (real files)" do
		alias PhotoTagger.TempFileHelper

		setup do
			temp_dir = TempFileHelper.setup_temp_storage(%{})
			folder = folder_fixture_with_files(%{temp_dir: temp_dir})
			{:ok, temp_dir: temp_dir, folder: folder}
		end

		test "update_photo/2 with same manual_order succeeds", %{folder: folder} do
			# Create photos with sequential manual_order
			_photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "photo1.jpg"})
			_photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "photo2.jpg"})
			photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "photo3.jpg"})

			# Update photo3's manual_order to same value (no reorder triggered)
			assert {:ok, %{photo: updated}} = Gallery.update_photo(photo3, %{"manual_order" => 3})
			assert updated.manual_order == 3
		end

		test "update_photo/2 with different manual_order reorders photos", %{folder: folder} do
			_photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 1})
			_photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 2})
			photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 3})

			assert {:ok, %{photo: updated}} = Gallery.update_photo(photo3, %{"manual_order" => 1})
			assert updated.manual_order == 1
		end
	end
end
