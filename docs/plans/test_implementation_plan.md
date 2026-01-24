# Test Implementation Plan

## Overview

This document provides a comprehensive plan for implementing a full test suite for the Phoenix Photo Tagger application. The plan is structured in phases, with each phase building on infrastructure from previous phases.

## Known Bugs Requiring Regression Tests

Based on the requirements, these bugs need specific regression tests:

1. **Gallery view settings lost on photo selection** - When selecting a new photo, the following settings were incorrectly reset:
   - Sort order (manual vs. date)
   - Magnification/zoom level
   - Page number
   - Multiselect toggle state
   - Group collapse toggle state

2. **Gallery not refreshed after photo update** - When saving updates to a photo, the gallery panel and photo panel did not refresh to show the updated data.

## File Operations Testing Strategy

**Key Principle:** Real file and folder operations should only be used when testing functions that directly manipulate the filesystem. Most tests should use mocked folder operations for simplicity and speed.

### When to Use Real File Operations

Use real temp directories and actual file creation **only** for tests that verify:
- Creating a photo (verifying image files are stored correctly)
- Deleting a photo (verifying image files are removed)
- Renaming a photo (verifying image files are renamed)
- Moving a photo to a different folder (verifying files are relocated)
- Creating a folder (verifying directory is created)
- Retrieving a folder (verifying directory exists)
- Deleting a folder (verifying directory and contents are removed)
- Renaming a folder (verifying directory is renamed)

These tests live primarily in **Phase 3: File Operations Tests**.

### When to Use Mocked Operations

All other tests should use mocked fixtures that:
- Insert records directly into the database without creating actual files
- Skip Waffle upload processing
- Create folder records without filesystem directories

This includes most tests in:
- Phase 1: Gallery Context (except create/delete/rename tests)
- Phase 2: Access Control
- Phase 5: Controller tests (except upload endpoints)
- Phase 6: LiveView tests (except photo creation/deletion flows)
- Phase 7: Utility tests

## Test Infrastructure Setup

### Phase 0: Infrastructure and Fixtures

Create reusable test infrastructure before writing actual tests.

#### File: `test/support/temp_file_helper.ex`

Helper module for managing temporary directories and test files.

**Functions to implement:**

```elixir
@doc """
Creates a unique temp directory for a test and configures Waffle to use it.
Returns the path to the temp directory.
Automatically cleans up on test exit via on_exit callback.
"""
def setup_temp_storage(context)

@doc """
Creates a test image file at the given path.
Generates a simple 100x100 pixel JPEG using ImageMagick's convert command.
Returns {:ok, path} or {:error, reason}.
"""
def create_test_image(path, filename)

@doc """
Creates a Plug.Upload struct from a file path.
This mimics what Phoenix receives from file uploads.
"""
def create_upload_from_file(file_path, original_filename)

@doc """
Verifies that a file exists at the expected Waffle storage path.
Returns true/false.
"""
def image_exists?(photo, version)

@doc """
Returns the full path to an uploaded image version.
"""
def get_image_path(photo, version)
```

**Implementation notes:**
- Use `System.tmp_dir!()` and `System.unique_integer()` for unique temp dirs
- Store temp path in test context for easy access
- Use `on_exit` callback to clean up with `File.rm_rf!/1`
- Configure Waffle via `Application.put_env(:waffle, :storage_dir_prefix, temp_path)`
- For creating test images, shell out to ImageMagick: `convert -size 100x100 xc:blue #{path}`

#### File: `test/support/fixtures/gallery_fixtures.ex` (REPLACE EXISTING)

Complete rewrite of the broken fixture file. Provides both **mocked** fixtures (for most tests) and **real** fixtures (for file operation tests).

**Mocked Fixtures (default - no filesystem operations):**

```elixir
@doc """
Creates a folder record directly in the database WITHOUT creating a filesystem directory.
Use for most tests that don't need to verify filesystem operations.
Optionally accepts attrs to override defaults: %{name: "custom", is_public: true}
Returns the created Folder struct.
"""
def folder_fixture(attrs \\ %{})

@doc """
Creates a photo record directly in the database WITHOUT uploading actual files.
Inserts a minimal photo record with required fields populated.
Use for most tests that don't need to verify filesystem operations.
Requires a folder_id in attrs.
Optionally accepts other attrs: %{name: "test.jpg", description: "...", is_public: true}
Returns the created Photo struct.
"""
def photo_fixture(attrs)
```

**Real Fixtures (for file operation tests):**

```elixir
@doc """
Creates a folder with a unique name AND creates the actual filesystem directory.
Requires temp_dir in attrs (from TempFileHelper).
Uses Gallery.create_folder/1 to ensure directory is created.
Returns the created Folder struct.
"""
def folder_fixture_with_files(attrs)

@doc """
Creates a photo with a real uploaded image file.
Requires a temp_dir in attrs (from TempFileHelper).
Requires a folder created with folder_fixture_with_files.
Creates a test image file, creates Plug.Upload struct, calls Gallery.create_photo/1.
Returns the created Photo struct.
"""
def photo_fixture_with_files(attrs)

@doc """
Creates a complete test scenario with real folder, photos, and tags on the filesystem.
Returns %{folder: folder, photos: [photo1, photo2, ...], tags: [tag1, tag2, ...]}
Use for integration tests that need real files.
Requires temp_dir in attrs.
"""
def gallery_scenario_fixture_with_files(attrs)
```

**Shared Fixtures (no filesystem needed):**

```elixir
@doc """
Creates a tag with a unique name.
Optionally accepts attrs to override name: %{name: "landscape"}
Uses Gallery context to create (which handles get_or_create logic).
Returns the created Tag struct.
"""
def tag_fixture(attrs \\ %{})

@doc """
Creates a photo-tag association.
Accepts %{photo: photo, tag: tag} or %{photo: photo, tag_name: "string"}
Returns {:ok, %PhotoTag{}}.
"""
def photo_tag_fixture(attrs)

@doc """
Creates a complete test scenario with mocked folder, photos, and tags (no filesystem).
Returns %{folder: folder, photos: [photo1, photo2, ...], tags: [tag1, tag2, ...]}
Use for most tests.
"""
def gallery_scenario_fixture(attrs \\ %{})
```

**Default values:**
- Folder: `%{name: "folder#{unique_integer()}", is_public: true}`
- Photo: `%{name: "photo#{unique_integer()}.jpg", is_public: true, image_last_modified: DateTime.utc_now()}`
- Tag: `%{name: "tag#{unique_integer()}"}`

### Phase 1: Gallery Context Tests (40-50 tests)

#### File: `test/photo_tagger/gallery_test.exs` (EXPAND EXISTING)

Replace the existing 8 basic tests with comprehensive coverage.

**Setup (using mocked fixtures for most tests):**
```elixir
setup do
  # Most tests use mocked fixtures - no temp_dir needed
  folder = folder_fixture()
  {:ok, folder: folder}
end
```

**Setup for tests that need real files (create/delete/rename operations):**
```elixir
setup do
  temp_dir = TempFileHelper.setup_temp_storage(%{})
  folder = folder_fixture_with_files(%{temp_dir: temp_dir})
  {:ok, temp_dir: temp_dir, folder: folder}
end
```

**Test groups:**

##### Photo CRUD Operations (10 tests)

1. `test "list_photos/0 returns all public photos"` - Create 3 public photos, verify list returns all 3
2. `test "list_photos/1 with include_private: true returns all photos"` - Create 2 public, 1 private, verify with/without flag
3. `test "get_photo!/1 returns photo with given id"` - Create photo, fetch by id, assert equal
4. `test "get_photo!/1 raises when photo is private and include_private is false"` - Create private photo, assert_raise Ecto.NoResultsError
5. `test "create_photo/1 with valid data creates a photo"` - Create photo with fixture, verify all fields
6. `test "create_photo/1 with invalid data returns error changeset"` - Pass invalid attrs (missing required fields), assert {:error, changeset}
7. `test "create_photo/1 auto-assigns manual_order"` - Create 3 photos, verify manual_order is 1, 2, 3
8. `test "update_photo/2 with valid data updates the photo"` - Update name, description, verify changes
9. `test "update_photo/2 renames image files when name changes"` - Update name, verify old file gone, new file exists
10. `test "delete_photo/1 deletes the photo and files"` - Create photo, delete, verify DB and files gone

##### Tag Operations (8 tests)

11. `test "list_tags/0 returns all tags sorted by name"` - Create tags in random order, verify sorted
12. `test "add_tag_to_photo/2 creates association"` - Add tag to photo, preload, verify in tags list
13. `test "add_tag_to_photo/2 creates tag if it doesn't exist"` - Add non-existent tag, verify tag created
14. `test "add_tag_to_photo/2 is idempotent"` - Add same tag twice, verify only one association
15. `test "remove_tag_from_photo/2 removes association"` - Add tag, remove tag, verify gone
16. `test "remove_tag_from_photo/2 returns ok when tag not on photo"` - Remove non-existent tag, assert {:ok, nil}
17. `test "get_related_tags/1 returns tags from photos with overlapping tags"` - Complex scenario with multiple photos and tag overlaps
18. `test "tag names are case insensitive"` - Create tag "Sunset", try to add "sunset", verify same tag

##### Folder Operations (8 tests)

19. `test "list_folders/0 returns all public folders sorted by name"` - Create folders, verify sorted and public only
20. `test "list_folders/1 with include_private: true returns all folders"` - Create public and private folders, verify flag
21. `test "get_folder_by_name!/1 returns folder"` - Create folder, fetch by name
22. `test "create_folder/1 creates folder in database and filesystem"` - Create folder, verify DB and directory exist
23. `test "create_folder/1 returns error if directory creation fails"` - Mock directory creation failure
24. `test "update_folder/2 updates folder attributes"` - Update is_public, verify change
25. `test "update_folder/2 renames directory when name changes"` - Update name, verify old dir gone, new dir exists
26. `test "delete_folder/1 deletes folder, photos, and filesystem directory"` - Create folder with photos, delete, verify cleanup

##### Photo Listing and Filtering (15 tests)

27. `test "list_photos/1 with sort: :date orders by inserted_at desc and name"` - Create photos with different timestamps, and two photos with same timestamp and different name, verify order
28. `test "list_photos/1 with sort: :manual orders by manual_order asc"` - Create photos with manual_order values, verify order
29. `test "list_photos_by_folder/1 returns only photos in folder"` - Create 2 folders with photos, verify filtering
30. `test "list_photos_by_all_tags/1 returns photos with all specified tags (AND logic)"` - Tag photos, query with multiple tags
31. `test "list_photos_by_all_tags/1 with empty list returns all photos"` - Pass [], verify all photos returned
32. `test "list_photos_by_all_tags/1 with nil returns untagged photos"` - Create tagged and untagged photos, pass nil, verify only untagged
33. `test "list_photos_by_tags/1 with include filters photos with all included tags"` - Test %{include: [tag1, tag2], exclude: []}
34. `test "list_photos_by_tags/1 with exclude filters out photos with excluded tags"` - Test %{include: [], exclude: [tag1]}
35. `test "list_photos_by_tags/1 with both include and exclude"` - Complex scenario combining both
36. `test "list_photos_by_folder_and_tags/2 combines folder and tag filtering"` - Create multi-folder scenario, test combined filters
37. `test "list_tags_by_folder/1 returns only tags in that folder"` - Create 2 folders with different tags, verify filtering
38. `test "list_tags_by_photos/1 returns tags from specified photos"` - Create photos with overlapping tags, verify correct tags returned
39. `test "list_folders_include_tags/0 returns folders with their tag arrays"` - Create folders with tagged photos, verify tag aggregation
40. `test "get_photos_by_ids/1 returns photos in any order"` - Create photos, fetch by id list, verify all returned
41. `test "get_next_manual_order/1 returns 1 for empty folder"` - Empty folder, assert next order is 1

##### Manual Ordering (5 tests)

42. `test "reorder_photos_for_insert/3 shifts photos up when inserting new photo"` - Create 5 photos, insert at position 3, verify shifts
43. `test "reorder_photos_for_insert/3 handles moving photo down (earlier position)"` - Move photo from position 5 to 2, verify shifts
44. `test "reorder_photos_for_insert/3 handles moving photo up (later position)"` - Move photo from position 2 to 5, verify shifts
45. `test "update_photo/2 with manual_order updates position and reorders others"` - Change manual_order, verify photo moved and others shifted
46. `test "create_photo/1 assigns next manual_order automatically"` - Verified in test #7 above

##### Additional Tests (3 tests)

47. `test "update_photo_changeset/2 returns changeset"` - Create photo, get changeset, verify it's valid
48. `test "new_photo_changeset/1 returns changeset for new photo"` - Create empty changeset, verify valid
49. `test "delete_orphan_tags/0 removes tags with no photos"` - Create tag, add to photo, remove from photo, call delete_orphan_tags, verify tag deleted

### Phase 2: Public/Private Access Control Tests (15-20 tests)

#### File: `test/photo_tagger/gallery_access_control_test.exs`

Test that the `include_private` flag works correctly across all functions.

**Setup (using mocked fixtures - no filesystem needed for access control tests):**
```elixir
setup do
  public_folder = folder_fixture(%{is_public: true})
  private_folder = folder_fixture(%{is_public: false})
  public_photo_in_public_folder = photo_fixture(%{folder_id: public_folder.id, is_public: true})
  private_photo_in_public_folder = photo_fixture(%{folder_id: public_folder.id, is_public: false})
  public_photo_in_private_folder = photo_fixture(%{folder_id: private_folder.id, is_public: true})
  private_photo_in_private_folder = photo_fixture(%{folder_id: private_folder.id, is_public: false})
  {:ok,
    public_folder: public_folder,
    private_folder: private_folder,
    # ... etc
  }
end
```

**Tests:**

1. `test "list_photos/0 excludes private photos"` - Verify private photos not returned by default
2. `test "list_photos/0 excludes photos in private folders"` - Public photo in private folder should be excluded
3. `test "list_photos/0 excludes private photos in public folders"` - Private photo in public folder excluded
4. `test "list_photos/1 with include_private: true includes all photos"` - Verify all combinations returned
5. `test "list_photos_by_folder/1 respects photo privacy"` - Test various combinations
6. `test "list_photos_by_folder/1 respects folder privacy"` - Private folder should return nothing by default
7. `test "list_photos_by_tags/1 excludes private photos"` - Tag filtering respects privacy
8. `test "list_photos_by_all_tags/1 excludes private photos"` - All tags filtering respects privacy
9. `test "list_photos_by_folder_and_tags/2 respects both privacy flags"` - Combined filtering
10. `test "list_folders/0 excludes private folders"` - Private folders not returned by default
11. `test "list_folders/1 with include_private: true includes private folders"` - All folders returned
12. `test "get_photo!/1 raises for private photo without flag"` - Assert_raise for private photo
13. `test "get_photo!/1 returns private photo with include_private: true"` - Private photo accessible with flag
14. `test "get_photos_by_ids/1 excludes private photos"` - Batch fetch respects privacy
15. `test "list_folders_include_tags/0 excludes private folders"` - Folder tag aggregation respects privacy

### Phase 3: File Operations Tests (10-15 tests)

#### File: `test/photo_tagger/gallery_file_operations_test.exs`

Test actual filesystem operations with real temp directories. **All tests in this file use real files.**

**Setup (always uses real files):**
```elixir
setup do
  temp_dir = TempFileHelper.setup_temp_storage(%{})
  folder = folder_fixture_with_files(%{temp_dir: temp_dir})
  {:ok, temp_dir: temp_dir, folder: folder}
end
```

**Tests:**

1. `test "create_photo/1 stores all image versions"` - Create photo, verify original, thumb, web_md, web_lg exist
2. `test "create_photo/1 stores images in correct folder path"` - Verify path is uploads/images/{folder_name}/
3. `test "create_photo/1 generates correct filenames for each version"` - Verify naming: name.jpg, name.thumb.webp, etc.
4. `test "update_photo/2 renames all image versions when name changes"` - Change name, verify all versions renamed
5. `test "update_photo/2 moves images when folder changes"` - Move photo to different folder, verify files moved
6. `test "update_photo/2 returns error if file rename fails"` - Create scenario where file rename fails
7. `test "delete_photo/1 removes all image versions from filesystem"` - Delete photo, verify all versions gone
8. `test "create_folder/1 creates directory at correct path"` - Verify directory created at storage_dir_prefix/uploads/images/{name}
9. `test "update_folder/2 renames directory when name changes"` - Rename folder, verify directory renamed
10. `test "update_folder/2 updates photo image paths"` - Rename folder, verify photos still accessible
11. `test "delete_folder/1 removes directory and all contents"` - Delete folder with photos, verify directory gone
12. `test "ImageUploader.validate/1 accepts valid extensions"` - Test .jpg, .jpeg, .png, .gif
13. `test "ImageUploader.validate/1 rejects invalid extensions"` - Test .txt, .pdf, etc.
14. `test "ImageUploader.storage_dir/2 generates correct path from folder name"` - Verify path generation
15. `test "ImageUploader.filename/2 generates correct names for each version"` - Verify filename generation

### Phase 4: WeightedList Unit Tests (5 tests)

#### File: `test/photo_tagger/weighted_list_test.exs`

Test the WeightedList module used for drift mode.

**Tests:**

1. `test "new/1 creates weighted list from keyword list"` - Create with [{:a, 1}, {:b, 2}], verify struct
2. `test "new/1 raises ArgumentError for empty list"` - Pass [], assert_raise ArgumentError
3. `test "sample/1 returns item from list"` - Create list, sample multiple times, verify all returns are in list
4. `test "sample/1 distribution respects weights over many samples"` - Create [{:a, 1}, {:b, 9}], sample 1000 times, verify ~10% vs ~90%
5. `test "new/1 accumulates weights correctly"` - Create list, verify acc_list field has correct accumulated values

### Phase 5: Controller Tests (15-20 tests)

#### File: `test/photo_tagger_web/controllers/photo_controller_test.exs` (REPLACE BROKEN FILE)

**Setup (mocked for most tests):**
```elixir
setup %{conn: conn} do
  folder = folder_fixture()
  {:ok, conn: conn, folder: folder}
end
```

**Setup for upload tests that need real files:**
```elixir
setup %{conn: conn} do
  temp_dir = TempFileHelper.setup_temp_storage(%{})
  folder = folder_fixture_with_files(%{temp_dir: temp_dir})
  {:ok, conn: conn, temp_dir: temp_dir, folder: folder}
end
```

**Tests:**

1. `test "GET /admin/photos/new renders form", %{conn: conn}` - Verify form page loads
2. `test "POST /admin/photos creates photo with valid data", %{conn: conn, folder: folder, temp_dir: temp_dir}` - Create photo via form, verify redirect
3. `test "POST /admin/photos creates multiple photos from multiple uploads"` - Upload multiple files, verify all created
4. `test "POST /admin/photos handles partial failure gracefully"` - Mix valid and invalid uploads, verify flash messages
5. `test "POST /admin/photos with invalid data shows error"` - Missing required fields, verify error
6. `test "GET /admin/photos/:id/edit renders edit form"` - Verify edit page loads with photo data
7. `test "build_url/2 generates correct URLs"` - Test URL generation with various params

#### File: `test/photo_tagger_web/controllers/folder_controller_test.exs`

**Tests:**

8. `test "GET /admin/edit-folders renders folder list"` - Verify page loads
9. `test "POST /admin/folders creates folder with valid data"` - Create folder, verify redirect and flash
10. `test "POST /admin/folders with duplicate name shows error"` - Try to create duplicate, verify error flash
11. `test "PUT /admin/folders/:folder updates folder"` - Update is_public, verify change
12. `test "PUT /admin/folders/:folder with name change renames directory"` - Rename folder, verify directory renamed
13. `test "POST /admin/folders/:folder/rename renames folder"` - Test rename endpoint
14. `test "DELETE /admin/folders/:folder deletes folder"` - Delete folder, verify redirect and flash

#### File: `test/photo_tagger_web/controllers/tag_controller_test.exs`

**Tests:**

15. `test "GET /admin/edit-tags renders tag list"` - Verify page loads with tags
16. `test "PUT /admin/tags/:tag updates tag name"` - Rename tag, verify change
17. `test "DELETE /admin/tags/:tag deletes tag"` - Delete tag, verify redirect and flash

### Phase 6: LiveView Tests (50-60 tests)

#### File: `test/photo_tagger_web/live/gallery_live/main_test.exs`

The most comprehensive test file covering the main gallery LiveView.

**Setup (using mocked fixtures for most LiveView tests):**
```elixir
import Phoenix.LiveViewTest

setup do
  # Most LiveView tests use mocked fixtures - no temp_dir needed
  folder = folder_fixture()
  photo = photo_fixture(%{folder_id: folder.id})
  {:ok, folder: folder, photo: photo}
end
```

**Setup for LiveView tests that need real files (photo creation/deletion flows):**
```elixir
setup do
  temp_dir = TempFileHelper.setup_temp_storage(%{})
  folder = folder_fixture_with_files(%{temp_dir: temp_dir})
  photo = photo_fixture_with_files(%{folder_id: folder.id, temp_dir: temp_dir})
  {:ok, temp_dir: temp_dir, folder: folder, photo: photo}
end
```

**Test groups:**

##### Mounting and Initial State (5 tests)

1. `test "mount/3 sets is_admin to false for public action"` - Mount :public action, verify is_admin false
2. `test "mount/3 sets is_admin to true for admin actions"` - Mount :index action, verify is_admin true
3. `test "mount/3 loads all folders and tags"` - Verify assigns populated
4. `test "mount/3 sets default zoom_level, multiselect_active, collapse_groups"` - Verify defaults
5. `test "mount/3 uses admin layout for admin routes, app layout for public"` - Verify layout assignment

##### Handle Params and URL Routing (10 tests)

6. `test "handle_params with folder param loads folder photos"` - Navigate to /folders/test, verify photos loaded
7. `test "handle_params with query_tags filters photos by tags"` - Navigate with ?query_tags[]=tag1, verify filtering
8. `test "handle_params with exclude_tags filters out photos"` - Navigate with exclude_tags, verify filtering
9. `test "handle_params with photo_id selects photo"` - Navigate to photo URL, verify selected
10. `test "handle_params with selected_photos selects multiple photos"` - Navigate with selected_photos[], verify multi-select
11. `test "handle_params with sort param sets sort order"` - Navigate with ?sort=date, verify sort applied
12. `test "handle_params with pg param sets page number"` - Navigate with ?pg=2, verify page set
13. `test "handle_params with pg_size param sets page size"` - Navigate with ?pg_size=50, verify size set
14. `test "handle_params reuses cached filtered_photos when params unchanged"` - Navigate to same URL twice, verify no redundant queries
15. `test "handle_params triggers scroll_to_top events when relevant params change"` - Verify push_event calls

##### Photo Selection Events (8 tests - includes regression tests)

16. `test "select_gallery_photo without ctrl selects single photo"` - Click photo, verify single selection
17. `test "select_gallery_photo with ctrl adds to selection in multiselect mode"` - Ctrl+click, verify added
18. `test "select_gallery_photo with ctrl replaces selection when multiselect inactive"` - Verify single select behavior
19. `test "select_gallery_group selects all photos in group"` - Click group, verify all selected
20. `test "select_gallery_group in multiselect mode toggles group selection"` - Multiselect mode, verify toggle
21. `test "REGRESSION: selecting photo preserves sort order"` - Set sort=manual, select photo, verify sort unchanged
22. `test "REGRESSION: selecting photo preserves zoom level"` - Set zoom, select photo, verify zoom unchanged
23. `test "REGRESSION: selecting photo preserves page number"` - Set pg=2, select photo, verify pg unchanged

##### UI State Toggle Events (5 tests)

24. `test "toggle_multiselect toggles multiselect_active"` - Trigger event, verify toggle
25. `test "toggle_collapse_groups toggles collapse_groups"` - Trigger event, verify toggle
26. `test "toggle_collapse_groups resets collapse_group_exceptions"` - Verify exceptions cleared
27. `test "toggle_collapse_single_group updates exceptions map"` - Collapse single group, verify exception added
28. `test "REGRESSION: toggling multiselect preserves other view settings"` - Verify sort, zoom, page preserved

##### Tag Management Events (8 tests)

29. `test "add_tag adds tag to photo and refreshes"` - Add tag, verify photo updated and lists refreshed
30. `test "add_tag creates new tag if it doesn't exist"` - Add non-existent tag, verify tag created
31. `test "remove_tag removes tag from photo and refreshes"` - Remove tag, verify update
32. `test "add_tag_bulk adds tag to all selected photos"` - Select multiple, add tag, verify all updated
33. `test "remove_tag_bulk removes tag from all selected photos"` - Select multiple, remove tag, verify all updated
34. `test "toggle_tag adds tag to query when not present"` - Toggle tag filter on
35. `test "toggle_tag removes tag from query when present"` - Toggle tag filter off
36. `test "toggle_exclude_tag adds tag to exclude list"` - Toggle exclude filter

##### Photo Update and Delete Events (6 tests - includes regression tests)

37. `test "update_photo updates photo and shows flash"` - Update photo, verify flash message
38. `test "update_photo with invalid data shows error flash"` - Invalid update, verify error flash
39. `test "REGRESSION: update_photo refreshes gallery panel"` - Update photo, verify gallery refreshed
40. `test "REGRESSION: update_photo refreshes selected photo in photo panel"` - Update photo, verify photo panel shows new data
41. `test "delete_photo removes photo and redirects"` - Delete photo, verify removed and redirect
42. `test "delete_photo_bulk deletes all selected photos"` - Select multiple, delete, verify all removed

##### Group Management Events (3 tests)

43. `test "set_group_bulk sets group for all selected photos"` - Select multiple, set group, verify all updated
44. `test "form_group_from_selected creates new group from timestamp"` - Form group, verify timestamp group created
45. `test "form_group_from_selected reuses existing group if all photos share one"` - Select photos with same group, form group, verify group reused

##### View Settings Events (5 tests - includes regression tests)

46. `test "zoom_in increases zoom_level"` - Trigger zoom_in, verify increment
47. `test "zoom_out decreases zoom_level"` - Trigger zoom_out, verify decrement
48. `test "zoom_in and zoom_out clamp between -9 and 9"` - Test boundaries
49. `test "change_sort updates sort order and triggers URL update"` - Change sort, verify URL push_patch
50. `test "REGRESSION: change_sort preserves other view settings"` - Change sort, verify zoom, page, multiselect preserved

##### Folder Navigation Events (2 tests)

51. `test "change_folder navigates to folder"` - Select folder, verify URL update
52. `test "change_folder with empty string navigates to all folders"` - Select "all", verify nil folder

##### Pagination Events (2 tests)

53. `test "change_page updates page number"` - Click next page, verify pg updated
54. `test "change_page triggers scroll to top"` - Verify scroll event pushed

##### Component Rendering (6 tests)

55. `test "gallery_header renders breadcrumb navigation"` - Verify breadcrumb with folder and tags
56. `test "gallery_header renders sort dropdown"` - Verify sort options
57. `test "gallery_header renders view controls (zoom, multiselect, collapse)"` - Verify buttons
58. `test "gallery renders photos with correct zoom level"` - Verify CSS classes based on zoom
59. `test "gallery renders pagination when needed"` - Verify pagination shows for large lists
60. `test "photo panel renders selected photo details"` - Verify photo info displayed

##### Utility Function Tests (3 tests)

61. `test "member_by_id?/2 returns true when item in list"` - Test helper function
62. `test "member_by_id?/2 returns false when item not in list"` - Test helper function
63. `test "simplify_photo/1 extracts only needed fields"` - Verify only :id, :name, :group, :image, :folder

#### File: `test/photo_tagger_web/live/gallery_live/drift_test.exs`

Test the drift/carousel mode.

**Tests:**

1. `test "mount/3 loads initial photo and starts timer"` - Verify photo loaded and timer set
2. `test "mount/3 selects random photo based on weights"` - Test WeightedList integration
3. `test "handle_info :next_photo advances to next photo"` - Verify photo progression
4. `test "drift mode respects public/private access control"` - Verify private photos excluded in public mode
5. `test "drift mode navigates between photos in folder"` - Test folder-scoped drift

### Phase 7: Utility Module Tests (10 tests)

#### File: `test/photo_tagger_web/live/gallery_live/util_test.exs`

Test utility functions used by LiveView.

**Tests:**

1. `test "build_url/7 generates correct public URLs"` - Test various param combinations for public routes
2. `test "build_url/7 generates correct admin URLs"` - Test admin=true flag
3. `test "build_url/7 handles nil folder"` - Verify /photos path
4. `test "build_url/7 handles folder with photo_id"` - Verify /folders/:folder/photos/:id path
5. `test "build_url/7 includes query_tags in query string"` - Verify tag params
6. `test "build_url/7 includes exclude_tags in query string"` - Verify exclude params
7. `test "build_url/7 includes selected_photos in query string"` - Verify multi-select params
8. `test "build_url/7 includes sort param only when :manual"` - Verify sort=manual in URL
9. `test "safe_integer_parse/2 parses valid integers"` - Test "123" -> 123
10. `test "safe_integer_parse/2 returns default for invalid input"` - Test "abc" -> default
11. `test "ceiling_div/2 calculates ceiling division correctly"` - Test various inputs: (10, 3) -> 4, (9, 3) -> 3

## Implementation Order

The phases should be implemented in order due to dependencies:

1. **Phase 0** - Must be completed first as all other tests depend on fixtures and temp file helpers
2. **Phase 1** - Gallery context tests are foundational and test core business logic
3. **Phase 2** - Access control tests build on Phase 1
4. **Phase 3** - File operations tests require fixtures from Phase 0
5. **Phase 4** - WeightedList tests are independent and can be done anytime
6. **Phase 5** - Controller tests require context and fixtures from Phases 0-1
7. **Phase 6** - LiveView tests are most complex and require all previous infrastructure
8. **Phase 7** - Utility tests are straightforward and can be done anytime after Phase 0

## Running the Tests

All tests should be runnable inside the Docker development container:

```bash
# Run all tests
docker compose -f docker-compose-dev.yml run dev_app mix test

# Run specific test file
docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger/gallery_test.exs

# Run specific test at line
docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger/gallery_test.exs:42
```

## Test Data Cleanup

All tests must clean up after themselves:

- **Database**: Ecto Sandbox automatically rolls back all transactions after each test
- **Filesystem**: TempFileHelper's `on_exit` callback removes temp directories
- **Waffle config**: Each test configures Waffle to use its own temp directory

## Additional Notes

### Testing Waffle Uploads

**For most tests**, use mocked fixtures that skip Waffle entirely:

```elixir
# Mocked approach - no temp_dir needed
setup do
  folder = folder_fixture()
  photo = photo_fixture(%{folder_id: folder.id})
  {:ok, folder: folder, photo: photo}
end
```

**For tests that need to verify actual file operations** (Phase 3 and select other tests):

```elixir
# Real file approach - only for file operation tests
setup do
  temp_dir = TempFileHelper.setup_temp_storage(%{})
  # This configures Waffle for this test:
  # Application.put_env(:waffle, :storage_dir_prefix, temp_dir)
  {:ok, temp_dir: temp_dir}
end

# Creating a photo with real file:
folder = folder_fixture_with_files(%{temp_dir: temp_dir})
image_path = Path.join(temp_dir, "test.jpg")
TempFileHelper.create_test_image(temp_dir, "test.jpg")
upload = TempFileHelper.create_upload_from_file(image_path, "test.jpg")
attrs = %{
  "folder_id" => folder.id,
  "image" => upload,
  "image_last_modified" => DateTime.utc_now()
}
{:ok, photo} = Gallery.create_photo(attrs)

# Verifying file exists:
assert TempFileHelper.image_exists?(photo, :original)
assert TempFileHelper.image_exists?(photo, :thumb)
```

### Testing LiveView Events

Pattern for testing LiveView events (using mocked fixtures):

```elixir
test "event_name does something", %{conn: conn, folder: folder} do
  # Create test data using mocked fixtures
  photo = photo_fixture(%{folder_id: folder.id})

  # Mount the LiveView
  {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

  # Trigger event
  html = render_click(view, "event_name", %{param: "value"})

  # Assert changes
  assert view.assigns.some_value == expected_value
  assert html =~ "expected content"
end
```

### Regression Test Examples

For the known bugs, here's how to structure regression tests. These use mocked fixtures since they don't verify filesystem operations:

```elixir
# Bug: Gallery view settings lost on photo selection
test "REGRESSION: selecting photo preserves sort order", %{conn: conn, folder: folder} do
  photo1 = photo_fixture(%{folder_id: folder.id})
  photo2 = photo_fixture(%{folder_id: folder.id})

  # Navigate with sort=manual
  {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}?sort=manual")
  assert view.assigns.sort == :manual

  # Select a photo
  render_click(view, "select_gallery_photo", %{
    "photo_id" => photo1.id,
    "ctrl_key_pressed" => false
  })

  # Verify sort is still manual
  assert view.assigns.sort == :manual
end

# Bug: Gallery not refreshed after photo update
test "REGRESSION: update_photo refreshes gallery panel", %{conn: conn, folder: folder} do
  photo = photo_fixture(%{folder_id: folder.id, name: "old_name.jpg"})

  {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

  # Update photo name
  render_click(view, "update_photo", %{
    "photo_id" => photo.id,
    "photo" => %{"name" => "new_name.jpg"}
  })

  # Verify gallery shows updated name
  filtered_photos = view.assigns.filtered_photos
  assert Enum.any?(filtered_photos, &(&1.name == "new_name.jpg"))
  refute Enum.any?(filtered_photos, &(&1.name == "old_name.jpg"))
end
```

## Total Test Count Estimate

- Phase 0: Infrastructure (no tests, just setup code)
- Phase 1: Gallery Context - 49 tests
- Phase 2: Access Control - 15 tests
- Phase 3: File Operations - 15 tests
- Phase 4: WeightedList - 5 tests
- Phase 5: Controllers - 17 tests
- Phase 6: LiveView - 63 tests
- Phase 7: Utilities - 11 tests

**Total: ~175 comprehensive tests**

This provides excellent coverage of all major functionality while maintaining focus on the most critical paths and known bug scenarios.
