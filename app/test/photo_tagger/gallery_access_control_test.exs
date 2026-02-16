defmodule PhotoTagger.GalleryAccessControlTest do
  @moduledoc """
  Tests for public/private access control in the Gallery context.
  Verifies that the `include_private` flag works correctly across all functions.
  """

  use PhotoTagger.DataCase, async: true

  alias PhotoTagger.Gallery

  import PhotoTagger.GalleryFixtures

  describe "photo access control" do
    setup do
      public_folder = folder_fixture(%{visibility_type: :public})
      private_folder = folder_fixture(%{visibility_type: :private})

      public_photo_in_public_folder =
        photo_fixture(%{
          folder_id: public_folder.id,
          is_public: true,
          name: "public_in_public.jpg"
        })

      private_photo_in_public_folder =
        photo_fixture(%{
          folder_id: public_folder.id,
          is_public: false,
          name: "private_in_public.jpg"
        })

      public_photo_in_private_folder =
        photo_fixture(%{
          folder_id: private_folder.id,
          is_public: true,
          name: "public_in_private.jpg"
        })

      private_photo_in_private_folder =
        photo_fixture(%{
          folder_id: private_folder.id,
          is_public: false,
          name: "private_in_private.jpg"
        })

      {:ok,
       public_folder: public_folder,
       private_folder: private_folder,
       public_photo_in_public_folder: public_photo_in_public_folder,
       private_photo_in_public_folder: private_photo_in_public_folder,
       public_photo_in_private_folder: public_photo_in_private_folder,
       private_photo_in_private_folder: private_photo_in_private_folder}
    end

    test "list_photos/0 excludes private photos", context do
      photos = Gallery.list_photos()
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo_in_public_folder.id in photo_ids
      refute context.private_photo_in_public_folder.id in photo_ids
    end

    test "list_photos/0 excludes photos in private folders", context do
      photos = Gallery.list_photos()
      photo_ids = Enum.map(photos, & &1.id)

      # Public photo in private folder should be excluded
      refute context.public_photo_in_private_folder.id in photo_ids
    end

    test "list_photos/0 excludes private photos in public folders", context do
      photos = Gallery.list_photos()
      photo_ids = Enum.map(photos, & &1.id)

      # Private photo in public folder should be excluded
      refute context.private_photo_in_public_folder.id in photo_ids
    end

    test "list_photos/1 with include_private: true includes all photos", context do
      photos = Gallery.list_photos(include_private: true)
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo_in_public_folder.id in photo_ids
      assert context.private_photo_in_public_folder.id in photo_ids
      assert context.public_photo_in_private_folder.id in photo_ids
      assert context.private_photo_in_private_folder.id in photo_ids
    end

    test "get_photo!/1 raises for private photo without flag", context do
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(context.private_photo_in_public_folder.id)
      end
    end

    test "get_photo!/1 returns private photo with include_private: true", context do
      photo = Gallery.get_photo!(context.private_photo_in_public_folder.id, include_private: true)
      assert photo.id == context.private_photo_in_public_folder.id
    end

    test "get_photos_by_ids/1 excludes private photos", context do
      all_ids = [
        context.public_photo_in_public_folder.id,
        context.private_photo_in_public_folder.id,
        context.public_photo_in_private_folder.id,
        context.private_photo_in_private_folder.id
      ]

      photos = Gallery.get_photos_by_ids(all_ids)
      photo_ids = Enum.map(photos, & &1.id)

      # Only public photo in public folder should be returned
      assert length(photos) == 1
      assert context.public_photo_in_public_folder.id in photo_ids
    end

    test "get_photos_by_ids/1 with include_private: true returns all photos", context do
      all_ids = [
        context.public_photo_in_public_folder.id,
        context.private_photo_in_public_folder.id,
        context.public_photo_in_private_folder.id,
        context.private_photo_in_private_folder.id
      ]

      photos = Gallery.get_photos_by_ids(all_ids, include_private: true)

      assert length(photos) == 4
    end
  end

  describe "folder access control" do
    setup do
      public_folder = folder_fixture(%{visibility_type: :public, name: "public_folder"})
      private_folder = folder_fixture(%{visibility_type: :private, name: "private_folder"})

      # Add photos with tags for list_folders_include_tags test
      public_photo = photo_fixture(%{folder_id: public_folder.id, is_public: true})
      private_photo = photo_fixture(%{folder_id: private_folder.id, is_public: true})

      Gallery.add_tag_to_photo(public_photo, "public_tag")
      Gallery.add_tag_to_photo(private_photo, "private_tag")

      {:ok, public_folder: public_folder, private_folder: private_folder}
    end

    test "list_folders/0 excludes private folders", context do
      folders = Gallery.list_folders()
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      refute context.private_folder.name in folder_names
    end

    test "list_folders/1 with include_private: true includes private folders", context do
      folders = Gallery.list_folders(include_private: true)
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      assert context.private_folder.name in folder_names
    end

    test "list_folders_include_tags/0 excludes private folders", context do
      folders = Gallery.list_folders_include_tags()
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      refute context.private_folder.name in folder_names
    end

    test "list_folders_include_tags/1 with include_private: true includes private folders",
         context do
      folders = Gallery.list_folders_include_tags(include_private: true)
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      assert context.private_folder.name in folder_names
    end
  end

  describe "unlisted folder access control" do
    setup do
      public_folder = folder_fixture(%{visibility_type: :public, name: "unlisted_test_public"})

      unlisted_folder =
        folder_fixture(%{visibility_type: :unlisted, name: "unlisted_test_unlisted"})

      private_folder = folder_fixture(%{visibility_type: :private, name: "unlisted_test_private"})

      # Add photos to each folder
      public_photo = photo_fixture(%{folder_id: public_folder.id, is_public: true})
      unlisted_photo = photo_fixture(%{folder_id: unlisted_folder.id, is_public: true})
      private_photo = photo_fixture(%{folder_id: private_folder.id, is_public: true})

      Gallery.add_tag_to_photo(public_photo, "test_tag")
      Gallery.add_tag_to_photo(unlisted_photo, "test_tag")
      Gallery.add_tag_to_photo(private_photo, "test_tag")

      {:ok,
       public_folder: public_folder,
       unlisted_folder: unlisted_folder,
       private_folder: private_folder,
       public_photo: public_photo,
       unlisted_photo: unlisted_photo,
       private_photo: private_photo}
    end

    test "list_folders/0 excludes unlisted folders", context do
      folders = Gallery.list_folders()
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      refute context.unlisted_folder.name in folder_names
      refute context.private_folder.name in folder_names
    end

    test "list_folders/1 with include_private: true includes unlisted folders", context do
      folders = Gallery.list_folders(include_private: true)
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      assert context.unlisted_folder.name in folder_names
      assert context.private_folder.name in folder_names
    end

    test "list_folders_include_tags/0 excludes unlisted folders", context do
      folders = Gallery.list_folders_include_tags()
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      refute context.unlisted_folder.name in folder_names
      refute context.private_folder.name in folder_names
    end

    test "list_folders_include_tags/1 with include_private: true includes unlisted folders",
         context do
      folders = Gallery.list_folders_include_tags(include_private: true)
      folder_names = Enum.map(folders, & &1.name)

      assert context.public_folder.name in folder_names
      assert context.unlisted_folder.name in folder_names
      assert context.private_folder.name in folder_names
    end

    test "list_photos_by_folder/1 returns photos from unlisted folder", context do
      # Unlisted folders are accessible by direct link (i.e., by folder name)
      photos = Gallery.list_photos_by_folder(context.unlisted_folder.name)

      assert length(photos) == 1
      assert hd(photos).id == context.unlisted_photo.id
    end

    test "list_photos/0 excludes photos from unlisted folders", context do
      # Photos in unlisted folders should NOT be accessible when querying all photos
      # They are only accessible when querying by folder name directly
      photos = Gallery.list_photos()
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo.id in photo_ids
      refute context.unlisted_photo.id in photo_ids
      refute context.private_photo.id in photo_ids
    end
  end

  describe "filtered listing access control" do
    setup do
      public_folder = folder_fixture(%{visibility_type: :public, name: "filter_public_folder"})
      private_folder = folder_fixture(%{visibility_type: :private, name: "filter_private_folder"})

      public_photo =
        photo_fixture(%{
          folder_id: public_folder.id,
          is_public: true,
          name: "filterable_public.jpg"
        })

      private_photo =
        photo_fixture(%{
          folder_id: public_folder.id,
          is_public: false,
          name: "filterable_private.jpg"
        })

      photo_in_private_folder =
        photo_fixture(%{
          folder_id: private_folder.id,
          is_public: true,
          name: "in_private_folder.jpg"
        })

      # Add the same tag to all photos for filtering tests
      Gallery.add_tag_to_photo(public_photo, "shared_tag")
      Gallery.add_tag_to_photo(private_photo, "shared_tag")
      Gallery.add_tag_to_photo(photo_in_private_folder, "shared_tag")

      {:ok,
       public_folder: public_folder,
       private_folder: private_folder,
       public_photo: public_photo,
       private_photo: private_photo,
       photo_in_private_folder: photo_in_private_folder}
    end

    test "list_photos_by_folder/1 respects photo privacy", context do
      photos = Gallery.list_photos_by_folder(context.public_folder.name)
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo.id in photo_ids
      refute context.private_photo.id in photo_ids
    end

    test "list_photos_by_folder/1 respects folder privacy", context do
      # Querying a private folder without include_private should return empty
      photos = Gallery.list_photos_by_folder(context.private_folder.name)

      assert photos == []
    end

    test "list_photos_by_folder/1 with include_private: true returns all photos", context do
      photos = Gallery.list_photos_by_folder(context.public_folder.name, include_private: true)
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo.id in photo_ids
      assert context.private_photo.id in photo_ids
    end

    test "list_photos_by_tags/1 excludes private photos", context do
      photos = Gallery.list_photos_by_tags(%{include: ["shared_tag"], exclude: []})
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo.id in photo_ids
      refute context.private_photo.id in photo_ids
      refute context.photo_in_private_folder.id in photo_ids
    end

    test "list_photos_by_all_tags/1 excludes private photos", context do
      photos = Gallery.list_photos_by_all_tags(["shared_tag"])
      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo.id in photo_ids
      refute context.private_photo.id in photo_ids
      refute context.photo_in_private_folder.id in photo_ids
    end

    test "list_photos_by_folder_and_tags/2 respects both privacy flags", context do
      photos =
        Gallery.list_photos_by_folder_and_tags(
          context.public_folder.name,
          %{include: ["shared_tag"], exclude: []}
        )

      photo_ids = Enum.map(photos, & &1.id)

      # Only public photo in public folder with the tag should be returned
      assert context.public_photo.id in photo_ids
      refute context.private_photo.id in photo_ids
    end

    test "list_photos_by_folder_and_tags/2 with include_private: true returns all matching photos",
         context do
      photos =
        Gallery.list_photos_by_folder_and_tags(
          context.public_folder.name,
          %{include: ["shared_tag"], exclude: []},
          include_private: true
        )

      photo_ids = Enum.map(photos, & &1.id)

      assert context.public_photo.id in photo_ids
      assert context.private_photo.id in photo_ids
    end
  end
end
