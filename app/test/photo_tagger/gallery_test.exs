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

    test "get_photo!/1 raises when photo is private and include_private is false", %{
      folder: folder
    } do
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

    # Regression: create_photo with string folder_id (from form params) must auto-assign
    # sequential manual_order. Previously failed due to string/integer mismatch.
    test "create_photo/1 with string folder_id assigns sequential manual_order", %{
      temp_dir: temp_dir,
      folder: folder
    } do
      photo1 =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: to_string(folder.id),
          name: "regression_test_1.jpg"
        })

      photo2 =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: to_string(folder.id),
          name: "regression_test_2.jpg"
        })

      assert photo1.manual_order == 1
      assert photo2.manual_order == 2
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

    test "list_photos/1 with sort: :date orders by inserted_at desc then name asc", %{
      folder: folder
    } do
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

    test "list_photos/1 with sort: :manual defaults to descending order", %{folder: folder} do
      _photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "third.jpg"})
      _photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "first.jpg"})
      _photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "second.jpg"})

      photos = Gallery.list_photos(sort: :manual, include_private: true)
      photo_names = Enum.map(photos, & &1.name)

      # Default direction is :desc (highest/newest first)
      assert photo_names == ["third.jpg", "second.jpg", "first.jpg"]
    end

    test "list_photos/1 with sort: :manual and sort_direction: :asc orders by manual_order ascending",
         %{
           folder: folder
         } do
      _photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "third.jpg"})
      _photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "first.jpg"})
      _photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "second.jpg"})

      photos = Gallery.list_photos(sort: :manual, sort_direction: :asc, include_private: true)
      photo_names = Enum.map(photos, & &1.name)

      assert photo_names == ["first.jpg", "second.jpg", "third.jpg"]
    end

    test "list_photos/1 with sort: :manual and sort_direction: :desc orders by manual_order descending",
         %{
           folder: folder
         } do
      _photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3, name: "third.jpg"})
      _photo2 = photo_fixture(%{folder_id: folder.id, manual_order: 1, name: "first.jpg"})
      _photo3 = photo_fixture(%{folder_id: folder.id, manual_order: 2, name: "second.jpg"})

      photos = Gallery.list_photos(sort: :manual, sort_direction: :desc, include_private: true)
      photo_names = Enum.map(photos, & &1.name)

      assert photo_names == ["third.jpg", "second.jpg", "first.jpg"]
    end

    test "list_photos/1 with sort: :date and sort_direction: :asc orders by date ascending", %{
      folder: folder
    } do
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

    test "list_photos/1 with sort: :date and sort_direction: :desc orders by date descending", %{
      folder: folder
    } do
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

    test "list_photos_by_all_tags/1 returns photos with all specified tags (AND logic)", %{
      folder: folder
    } do
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

    test "list_photos_by_tags/1 with include filters photos with all included tags", %{
      folder: folder
    } do
      photo1 = photo_fixture(%{folder_id: folder.id, name: "tagged.jpg"})
      _photo2 = photo_fixture(%{folder_id: folder.id, name: "untagged.jpg"})

      Gallery.add_tag_to_photo(photo1, "nature")

      photos =
        Gallery.list_photos_by_tags(%{include: ["nature"], exclude: []}, include_private: true)

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

    test "list_photos_by_tags/1 with exclude filters out photos with excluded tags", %{
      folder: folder
    } do
      photo1 = photo_fixture(%{folder_id: folder.id, name: "excluded.jpg"})
      photo2 = photo_fixture(%{folder_id: folder.id, name: "included.jpg"})

      Gallery.add_tag_to_photo(photo1, "rejected")

      photos =
        Gallery.list_photos_by_tags(%{include: [], exclude: ["rejected"]}, include_private: true)

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
      photos =
        Gallery.list_photos_by_tags(
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

      photos =
        Gallery.list_photos_by_folder_and_tags(
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

    test "get_next_manual_order/0 returns 1 when no photos exist" do
      assert Gallery.get_next_manual_order() == 1
    end

    test "get_next_manual_order/0 returns max + 1 across all folders", %{folder: folder} do
      other_folder = folder_fixture(%{name: "other_folder"})
      _photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 3})
      _photo2 = photo_fixture(%{folder_id: other_folder.id, manual_order: 7})

      assert Gallery.get_next_manual_order() == 8
    end

    test "get_next_manual_order/0 ignores folder boundaries", %{folder: folder} do
      other_folder = folder_fixture(%{name: "other_folder"})
      _photo1 = photo_fixture(%{folder_id: folder.id, manual_order: 10})
      _photo2 = photo_fixture(%{folder_id: other_folder.id, manual_order: 2})

      # Should return 11, not 3 — looks at all photos globally
      assert Gallery.get_next_manual_order() == 11
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
      _folder_c = folder_fixture(%{name: "c_folder", visibility_type: :public})
      _folder_a = folder_fixture(%{name: "a_folder", visibility_type: :public})
      _folder_private = folder_fixture(%{name: "b_private", visibility_type: :private})

      folders = Gallery.list_folders()
      folder_names = Enum.map(folders, & &1.name)

      # Should only include public folders, sorted
      assert folder_names == ["a_folder", "c_folder"]
    end

    test "list_folders/1 with include_private: true returns all folders" do
      folder_fixture(%{name: "public_folder", visibility_type: :public})
      folder_fixture(%{name: "private_folder", visibility_type: :private})

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
        Gallery.create_folder(%{"name" => "new_folder", "visibility_type" => "public"})

      assert folder.name == "new_folder"
      assert TempFileHelper.folder_exists?(folder)
    end

    test "update_folder/2 updates folder attributes", %{temp_dir: temp_dir} do
      folder = folder_fixture_with_files(%{temp_dir: temp_dir, visibility_type: "private"})

      assert {:ok, %{update_folder_db: updated}} =
               Gallery.update_folder(folder, %{
                 "name" => folder.name,
                 "visibility_type" => "public"
               })

      assert updated.visibility_type == :public
    end

    test "update_folder/2 renames directory when name changes", %{temp_dir: temp_dir} do
      folder = folder_fixture_with_files(%{temp_dir: temp_dir, name: "old_name"})

      # Verify old directory exists
      assert TempFileHelper.folder_exists?(folder)
      old_path = TempFileHelper.get_folder_path(folder)

      assert {:ok, %{update_folder_db: updated}} =
               Gallery.update_folder(folder, %{
                 "name" => "new_name",
                 "visibility_type" => to_string(folder.visibility_type)
               })

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
               Gallery.update_folder(folder, %{
                 "name" => "renamed_folder",
                 "visibility_type" => to_string(folder.visibility_type)
               })

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

  describe "cross-listing schema" do
    test "Photo schema has original_photo_id field" do
      folder = folder_fixture()
      photo = photo_fixture(%{folder_id: folder.id})

      # Verify the field exists and is nil for originals
      assert Map.has_key?(photo, :original_photo_id)
      assert photo.original_photo_id == nil
    end

    test "Photo schema has original_photo association" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Manually create a cross-listing by setting original_photo_id
      # Use same pattern as photo_fixture: bypass changeset for image field
      image = %{file_name: "cross_listing.jpg", updated_at: DateTime.utc_now()}

      {:ok, cross_listing} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross_listing.jpg",
            folder_id: folder_b.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image)
        |> Repo.insert()

      # Preload and verify association
      cross_listing_with_original = Repo.preload(cross_listing, :original_photo)
      assert cross_listing_with_original.original_photo.id == original.id
    end

    test "Photo schema has cross_listings association" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Manually create a cross-listing
      image = %{file_name: "cross_listing.jpg", updated_at: DateTime.utc_now()}

      {:ok, _cross_listing} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross_listing.jpg",
            folder_id: folder_b.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image)
        |> Repo.insert()

      # Preload and verify association
      original_with_cross_listings = Repo.preload(original, :cross_listings)
      assert length(original_with_cross_listings.cross_listings) == 1
    end
  end

  describe "cross-listing helper functions" do
    test "is_cross_listing?/1 returns true when original_photo_id is not nil" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Manually create a cross-listing
      image = %{file_name: "cross_listing.jpg", updated_at: DateTime.utc_now()}

      {:ok, cross_listing} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross_listing.jpg",
            folder_id: folder_b.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image)
        |> Repo.insert()

      assert Gallery.is_cross_listing?(cross_listing) == true
    end

    test "is_cross_listing?/1 returns false when original_photo_id is nil" do
      folder = folder_fixture()
      original = photo_fixture(%{folder_id: folder.id})

      assert Gallery.is_cross_listing?(original) == false
    end

    test "get_cross_listings/1 returns all cross-listings for an original photo" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})
      folder_c = folder_fixture(%{name: "folder_c"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Create two cross-listings
      image1 = %{file_name: "cross1.jpg", updated_at: DateTime.utc_now()}

      {:ok, cross_listing1} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross1.jpg",
            folder_id: folder_b.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image1)
        |> Repo.insert()

      image2 = %{file_name: "cross2.jpg", updated_at: DateTime.utc_now()}

      {:ok, cross_listing2} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross2.jpg",
            folder_id: folder_c.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image2)
        |> Repo.insert()

      cross_listings = Gallery.get_cross_listings(original)

      assert length(cross_listings) == 2
      cross_listing_ids = Enum.map(cross_listings, & &1.id) |> Enum.sort()
      assert cross_listing_ids == Enum.sort([cross_listing1.id, cross_listing2.id])
    end

    test "get_cross_listings/1 returns empty list when photo has no cross-listings" do
      folder = folder_fixture()
      original = photo_fixture(%{folder_id: folder.id})

      cross_listings = Gallery.get_cross_listings(original)

      assert cross_listings == []
    end

    test "get_cross_listings/1 returns empty list when called on a cross-listing itself" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Create a cross-listing
      image = %{file_name: "cross_listing.jpg", updated_at: DateTime.utc_now()}

      {:ok, cross_listing} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross_listing.jpg",
            folder_id: folder_b.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image)
        |> Repo.insert()

      # Call get_cross_listings on the cross-listing itself
      cross_listings = Gallery.get_cross_listings(cross_listing)

      assert cross_listings == []
    end
  end

  describe "create_cross_listing/2" do
    test "successfully creates cross-listing with copied metadata" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original =
        photo_fixture(%{
          folder_id: folder_a.id,
          name: "original.jpg",
          description: "Original description",
          notes: "Original notes",
          group: "original_group",
          is_public: false
        })

      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Verify copied metadata
      assert cross_listing.name == original.name
      assert cross_listing.description == original.description
      assert cross_listing.notes == original.notes
      assert cross_listing.group == original.group
      assert cross_listing.is_public == original.is_public
    end

    test "copies image and image_last_modified from original" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      image_timestamp = ~U[2025-01-15 10:30:00Z]

      original =
        photo_fixture(%{
          folder_id: folder_a.id,
          image_last_modified: image_timestamp
        })

      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Verify image field is copied
      assert cross_listing.image != nil
      assert cross_listing.image.file_name == original.image.file_name

      # Verify image_last_modified is copied
      assert DateTime.compare(cross_listing.image_last_modified, image_timestamp) == :eq
    end

    test "copies all tags from original" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})
      Gallery.add_tag_to_photo(original, "landscape")
      Gallery.add_tag_to_photo(original, "sunset")

      # Reload with tags
      original = Gallery.get_photo!(original.id) |> Repo.preload(:tags)

      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Reload cross-listing with tags
      cross_listing_with_tags = Gallery.get_photo!(cross_listing.id) |> Repo.preload(:tags)

      # Verify all tags copied
      assert length(cross_listing_with_tags.tags) == 2
      tag_names = Enum.map(cross_listing_with_tags.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["landscape", "sunset"]
    end

    test "sets original_photo_id to original's id" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      assert cross_listing.original_photo_id == original.id
    end

    test "sets folder_id to target folder" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      assert cross_listing.folder_id == folder_b.id
    end

    test "assigns manual_order appending to end of target folder" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      # Create existing photos in folder_b with manual orders 1, 2, 3
      _existing1 = photo_fixture(%{folder_id: folder_b.id, manual_order: 1})
      _existing2 = photo_fixture(%{folder_id: folder_b.id, manual_order: 2})
      _existing3 = photo_fixture(%{folder_id: folder_b.id, manual_order: 3})

      original = photo_fixture(%{folder_id: folder_a.id})

      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Should be appended after highest manual_order (3)
      assert cross_listing.manual_order == 4
    end

    test "returns error when photo is already a cross-listing" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})
      folder_c = folder_fixture(%{name: "folder_c"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Create a cross-listing
      image = %{file_name: "cross_listing.jpg", updated_at: DateTime.utc_now()}

      {:ok, cross_listing} =
        %Photo{}
        |> Ecto.Changeset.cast(
          %{
            name: "cross_listing.jpg",
            folder_id: folder_b.id,
            image_last_modified: DateTime.utc_now(),
            original_photo_id: original.id,
            manual_order: 1
          },
          [:name, :folder_id, :image_last_modified, :original_photo_id, :manual_order]
        )
        |> Ecto.Changeset.put_change(:image, image)
        |> Repo.insert()

      # Try to create a cross-listing from a cross-listing
      assert {:error, changeset} = Gallery.create_cross_listing(cross_listing, folder_c.id)
      assert "cannot create cross-listing from a cross-listing" in errors_on(changeset).base
    end

    test "returns error when target folder is same as original's folder" do
      folder_a = folder_fixture(%{name: "folder_a"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Try to create cross-listing in same folder
      assert {:error, changeset} = Gallery.create_cross_listing(original, folder_a.id)
      assert "cannot cross-list to the same folder" in errors_on(changeset).base
    end

    test "returns error when cross-listing already exists in target folder" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})

      # Create first cross-listing successfully
      assert {:ok, _cross_listing1} = Gallery.create_cross_listing(original, folder_b.id)

      # Try to create duplicate cross-listing in same folder
      assert {:error, changeset} = Gallery.create_cross_listing(original, folder_b.id)
      assert "cross-listing already exists in this folder" in errors_on(changeset).base
    end
  end

  describe "remove_cross_listing/1" do
    test "successfully removes a cross-listing from database" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Remove cross-listing
      assert {:ok, _deleted} = Gallery.remove_cross_listing(cross_listing)

      # Verify it's gone from database
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(cross_listing.id, include_private: true)
      end

      # Verify original still exists
      assert Gallery.get_photo!(original.id, include_private: true).id == original.id
    end

    test "returns error when called on original photo" do
      folder = folder_fixture()
      original = photo_fixture(%{folder_id: folder.id})

      assert {:error, :not_a_cross_listing} = Gallery.remove_cross_listing(original)
    end
  end

  describe "delete_photo/1 with cross-listings" do
    test "deletes cross-listing without deleting files when called on cross-listing" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Delete the cross-listing using delete_photo
      assert {:ok, _deleted} = Gallery.delete_photo(cross_listing)

      # Verify cross-listing is gone
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(cross_listing.id, include_private: true)
      end

      # Verify original still exists
      assert Gallery.get_photo!(original.id, include_private: true).id == original.id
    end
  end

  describe "update_photo/2 with cross-listings" do
    test "returns error when moving to folder with cross-listing" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})
      {:ok, _cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Try to move original to folder_b where cross-listing exists
      result = Gallery.update_photo(original, %{"folder_id" => folder_b.id})

      # Should return cross-listing error (before attempting file operations)
      assert {:error, :cross_listing_exists_in_target_folder} = result
    end

    test "allows folder change after cross-listing removed" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id})
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Remove cross-listing
      {:ok, _deleted} = Gallery.remove_cross_listing(cross_listing)

      # Now move validation should pass (file operation will fail due to missing files, but that's expected)
      result = Gallery.update_photo(original, %{"folder_id" => folder_b.id})

      # Should fail at file operation stage, not cross-listing validation
      # This proves the cross-listing check passed
      assert match?({:error, :update_file, _, _}, result)
    end

    test "non-folder-change updates work normally" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      original = photo_fixture(%{folder_id: folder_a.id, description: "Old description"})
      {:ok, _cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Update description only (not folder)
      result = Gallery.update_photo(original, %{"description" => "New description"})

      assert {:ok, %{photo: updated}} = result
      assert updated.description == "New description"
      assert updated.folder_id == folder_a.id
    end

    test "prevents moving cross-listing to same folder as original" do
      folder_a = folder_fixture(%{name: "folder_a"})
      folder_b = folder_fixture(%{name: "folder_b"})

      # Create original photo in folder A
      original = photo_fixture(%{folder_id: folder_a.id})

      # Create cross-listing in folder B
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Attempt to move cross-listing to folder A (same as original)
      result = Gallery.update_photo(cross_listing, %{"folder_id" => folder_a.id})

      # Should return error
      assert {:error, :cross_listing_in_same_folder_as_original} = result
    end
  end

  describe "cross-listing integration tests" do
    alias PhotoTagger.TempFileHelper

    setup do
      temp_dir = TempFileHelper.setup_temp_storage(%{})
      folder_a = folder_fixture_with_files(%{temp_dir: temp_dir, name: "folder_a"})
      folder_b = folder_fixture_with_files(%{temp_dir: temp_dir, name: "folder_b"})
      folder_c = folder_fixture_with_files(%{temp_dir: temp_dir, name: "folder_c"})
      {:ok, temp_dir: temp_dir, folder_a: folder_a, folder_b: folder_b, folder_c: folder_c}
    end

    test "complete cross-listing lifecycle: create, display, and remove", %{
      temp_dir: temp_dir,
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original photo with metadata and tags
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id,
          name: "original.jpg",
          description: "Test description",
          notes: "Test notes",
          group: "test_group",
          is_public: true
        })

      Gallery.add_tag_to_photo(original, "landscape")
      Gallery.add_tag_to_photo(original, "sunset")

      # Create cross-listing in folder_b
      assert {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Verify cross-listing has copied metadata
      assert cross_listing.name == "original.jpg"
      assert cross_listing.description == "Test description"
      assert cross_listing.notes == "Test notes"
      assert cross_listing.group == "test_group"
      assert cross_listing.is_public == true
      assert cross_listing.folder_id == folder_b.id
      assert cross_listing.original_photo_id == original.id

      # Verify cross-listing has copied tags
      cross_listing_with_tags =
        Gallery.get_photo!(cross_listing.id, include_private: true) |> Repo.preload(:tags)

      tag_names = Enum.map(cross_listing_with_tags.tags, & &1.name) |> Enum.sort()
      assert tag_names == ["landscape", "sunset"]

      # Verify cross-listing has assigned manual_order
      assert cross_listing.manual_order > 0

      # Verify original photo shows cross-listings
      original_with_cross_listings =
        Gallery.get_photo!(original.id, include_private: true) |> Repo.preload(:cross_listings)

      assert length(original_with_cross_listings.cross_listings) == 1
      assert hd(original_with_cross_listings.cross_listings).id == cross_listing.id

      # Verify is_cross_listing? helper
      assert Gallery.is_cross_listing?(cross_listing)
      refute Gallery.is_cross_listing?(original)

      # Verify get_cross_listings helper
      cross_listings = Gallery.get_cross_listings(original)
      assert length(cross_listings) == 1
      assert hd(cross_listings).id == cross_listing.id

      # Verify both photos appear in their respective folders
      folder_a_photos = Gallery.list_photos_by_folder(folder_a.name, include_private: true)
      folder_b_photos = Gallery.list_photos_by_folder(folder_b.name, include_private: true)
      assert Enum.any?(folder_a_photos, &(&1.id == original.id))
      assert Enum.any?(folder_b_photos, &(&1.id == cross_listing.id))

      # Remove cross-listing
      assert {:ok, _deleted} = Gallery.remove_cross_listing(cross_listing)

      # Verify cross-listing is gone from database
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(cross_listing.id, include_private: true)
      end

      # Verify original still exists with its files
      original_after = Gallery.get_photo!(original.id, include_private: true)
      assert original_after.id == original.id
      assert TempFileHelper.image_exists?(original_after, :original)
    end

    test "delete original photo cascades to all cross-listings and files", %{
      temp_dir: temp_dir,
      folder_a: folder_a,
      folder_b: folder_b,
      folder_c: folder_c
    } do
      # Create original photo
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id,
          name: "to_delete.jpg"
        })

      # Create cross-listings in two other folders
      {:ok, cross_listing_b} = Gallery.create_cross_listing(original, folder_b.id)
      {:ok, cross_listing_c} = Gallery.create_cross_listing(original, folder_c.id)

      # Verify files exist
      assert TempFileHelper.image_exists?(original, :original)

      # Delete original
      assert {:ok, _deleted} = Gallery.delete_photo(original)

      # Verify original is deleted from database
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(original.id, include_private: true)
      end

      # Verify cross-listings are deleted from database
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(cross_listing_b.id, include_private: true)
      end

      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(cross_listing_c.id, include_private: true)
      end

      # Verify files are deleted
      refute TempFileHelper.image_exists?(original, :original)
    end

    test "move original to folder with cross-listing returns error", %{
      temp_dir: temp_dir,
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original in folder_a with cross-listing in folder_b
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id,
          name: "to_move.jpg"
        })

      {:ok, _cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Try to move original to folder_b
      result = Gallery.update_photo(original, %{"folder_id" => folder_b.id})

      # Should fail with specific error
      assert {:error, :cross_listing_exists_in_target_folder} = result

      # After removing cross-listing, move should succeed
      cross_listing =
        Gallery.get_photo!(Gallery.get_cross_listings(original) |> hd() |> Map.get(:id),
          include_private: true
        )

      {:ok, _deleted} = Gallery.remove_cross_listing(cross_listing)

      # Now move should work
      assert {:ok, %{photo: moved}} =
               Gallery.update_photo(original, %{"folder_id" => folder_b.id})

      assert moved.folder_id == folder_b.id
    end

    test "cannot create cross-listing from a cross-listing", %{
      temp_dir: temp_dir,
      folder_a: folder_a,
      folder_b: folder_b,
      folder_c: folder_c
    } do
      # Create original and cross-listing
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id
        })

      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Try to create cross-listing from a cross-listing
      result = Gallery.create_cross_listing(cross_listing, folder_c.id)

      # Should fail
      assert {:error, %Ecto.Changeset{}} = result
    end

    test "cannot create cross-listing to same folder as original", %{
      temp_dir: temp_dir,
      folder_a: folder_a
    } do
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id
        })

      # Try to cross-list to same folder
      result = Gallery.create_cross_listing(original, folder_a.id)

      # Should fail
      assert {:error, %Ecto.Changeset{}} = result
    end

    test "cannot create duplicate cross-listing in same target folder", %{
      temp_dir: temp_dir,
      folder_a: folder_a,
      folder_b: folder_b
    } do
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id
        })

      # Create first cross-listing
      assert {:ok, _first} = Gallery.create_cross_listing(original, folder_b.id)

      # Try to create duplicate
      result = Gallery.create_cross_listing(original, folder_b.id)

      # Should fail
      assert {:error, %Ecto.Changeset{}} = result
    end

    test "remove_cross_listing returns error when called on original photo", %{
      temp_dir: temp_dir,
      folder_a: folder_a
    } do
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id
        })

      # Try to remove original as if it were a cross-listing
      result = Gallery.remove_cross_listing(original)

      # Should fail
      assert {:error, :not_a_cross_listing} = result
    end

    test "cross-listing metadata is independent after creation", %{
      temp_dir: temp_dir,
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original with initial metadata
      original =
        photo_fixture_with_files(%{
          temp_dir: temp_dir,
          folder_id: folder_a.id,
          description: "Original description"
        })

      Gallery.add_tag_to_photo(original, "original_tag")

      # Create cross-listing
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Update original's metadata
      {:ok, %{photo: updated_original}} =
        Gallery.update_photo(original, %{"description" => "Updated original"})

      Gallery.add_tag_to_photo(updated_original, "new_original_tag")

      # Update cross-listing's metadata
      {:ok, %{photo: updated_cross_listing}} =
        Gallery.update_photo(cross_listing, %{"description" => "Updated cross-listing"})

      Gallery.add_tag_to_photo(updated_cross_listing, "new_cross_listing_tag")

      # Verify they have different metadata
      original_final =
        Gallery.get_photo!(original.id, include_private: true) |> Repo.preload(:tags)

      cross_listing_final =
        Gallery.get_photo!(cross_listing.id, include_private: true) |> Repo.preload(:tags)

      assert original_final.description == "Updated original"
      assert cross_listing_final.description == "Updated cross-listing"

      original_tag_names = Enum.map(original_final.tags, & &1.name) |> Enum.sort()
      cross_listing_tag_names = Enum.map(cross_listing_final.tags, & &1.name) |> Enum.sort()

      assert original_tag_names == ["new_original_tag", "original_tag"]
      assert cross_listing_tag_names == ["new_cross_listing_tag", "original_tag"]
    end

    test "list_photos with exclude_cross_listings omits cross-listings", %{
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original photo in folder_a
      original = photo_fixture(%{folder_id: folder_a.id, name: "original.jpg"})

      # Create cross-listing in folder_b
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Without exclude_cross_listings, both appear
      all_photos = Gallery.list_photos(include_private: true)
      assert length(all_photos) == 2
      photo_ids = Enum.map(all_photos, & &1.id)
      assert original.id in photo_ids
      assert cross_listing.id in photo_ids

      # With exclude_cross_listings, only original appears
      originals_only = Gallery.list_photos(include_private: true, exclude_cross_listings: true)
      assert length(originals_only) == 1
      assert hd(originals_only).id == original.id
    end

    test "list_photos_by_tags with exclude_cross_listings omits cross-listings", %{
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original photo with tag
      original = photo_fixture(%{folder_id: folder_a.id, name: "tagged.jpg"})
      Gallery.add_tag_to_photo(original, "test_tag")

      # Create cross-listing in folder_b (copies tags)
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Without exclude_cross_listings, both appear
      all_tagged =
        Gallery.list_photos_by_tags(%{include: ["test_tag"], exclude: []}, include_private: true)

      assert length(all_tagged) == 2
      photo_ids = Enum.map(all_tagged, & &1.id)
      assert original.id in photo_ids
      assert cross_listing.id in photo_ids

      # With exclude_cross_listings, only original appears
      originals_only =
        Gallery.list_photos_by_tags(%{include: ["test_tag"], exclude: []},
          include_private: true,
          exclude_cross_listings: true
        )

      assert length(originals_only) == 1
      assert hd(originals_only).id == original.id
    end

    test "list_photos_by_folder still includes cross-listings (no regression)", %{
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original photo in folder_a
      original = photo_fixture(%{folder_id: folder_a.id, name: "original.jpg"})

      # Create cross-listing in folder_b
      {:ok, cross_listing} = Gallery.create_cross_listing(original, folder_b.id)

      # Folder_a should show only original
      folder_a_photos = Gallery.list_photos_by_folder(folder_a.name, include_private: true)
      assert length(folder_a_photos) == 1
      assert hd(folder_a_photos).id == original.id

      # Folder_b should show only cross-listing
      folder_b_photos = Gallery.list_photos_by_folder(folder_b.name, include_private: true)
      assert length(folder_b_photos) == 1
      assert hd(folder_b_photos).id == cross_listing.id
    end

    test "multiple cross-listings all filtered in 'All folders' view", %{
      folder_a: folder_a,
      folder_b: folder_b
    } do
      # Create original in folder_a
      original = photo_fixture(%{folder_id: folder_a.id, name: "multi.jpg"})

      # Create multiple cross-listings in folder_b and a third folder
      {:ok, _cross_listing_1} = Gallery.create_cross_listing(original, folder_b.id)
      folder_third = folder_fixture(%{name: "folder_third"})
      {:ok, _cross_listing_2} = Gallery.create_cross_listing(original, folder_third.id)

      # Without exclude_cross_listings, all three appear
      all_photos = Gallery.list_photos(include_private: true)
      assert length(all_photos) == 3

      # With exclude_cross_listings, only original appears
      originals_only = Gallery.list_photos(include_private: true, exclude_cross_listings: true)
      assert length(originals_only) == 1
      assert hd(originals_only).id == original.id
    end
  end
end
