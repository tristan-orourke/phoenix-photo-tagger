# Work Log

Track completed work and GitHub issues.

## Format

```markdown
### [YYYY-MM-DD] Issue Title (#issue-number)

**Summary**: Brief description of what was done
**Key Changes**:
- Change 1
- Change 2
**Files Modified**: List of key files changed
**Related**: Links to PRs, related issues, or decisions
```

---

## Completed Work

### [2026-02-16] Fix uploaded photos manual_order assignment

**Summary**: Fixed bug where newly uploaded photos were incorrectly assigned `manual_order = 1` instead of the next sequential number in the folder. The issue occurred because `folder_id` from form parameters came as a string but was used directly in database queries expecting an integer.

**Key Changes**:
- Modified `Gallery.get_next_manual_order/1` to convert string folder_id to integer before querying
- Added validation to raise clear error for invalid folder_id types (nil, atoms, etc.)
- Added comprehensive test coverage for string folder_id handling and error cases

**Files Modified**:
- `app/lib/photo_tagger/gallery.ex`
- `app/test/photo_tagger/gallery_test.exs`

**Related**: GitHub issue "uploaded photos should get a manual order number at the end of their folder"

### [2026-02-13] Cross-listing feature (#129)

**Summary**: Implemented cross-listing functionality allowing a single photo to appear in multiple folders without duplicating files on disk. Cross-listings are database references with independent metadata (tags, description, visibility) that share the original photo's image files.

**Key Changes**:
- Added `original_photo_id` field to photos table with cascade delete
- Implemented `create_cross_listing/2` and `remove_cross_listing/1` API functions
- Added validation to prevent cross-listing chains and folder conflicts
- Updated `ImageUploader.storage_dir/2` to resolve URLs using original photo's folder
- Added UI for single and bulk cross-listing in photo edit panel and multi-select
- Integrated cross-listing selection into photo upload form
- Added cross-listing badges and navigation links in photo info panel
- Comprehensive test coverage with 54 new tests

**Edge Cases Handled**:
- Cannot cross-list a cross-listing (chains prevented)
- Cannot cross-list to same folder as original
- Cannot move original to folder where cross-listing exists
- Cannot move cross-listing to same folder as original
- Deleting original cascades to all cross-listings with user warning
- Bulk operations filter to only original photos

**Files Modified**:
- `app/lib/photo_tagger/gallery.ex` (core API)
- `app/lib/photo_tagger/gallery/photo.ex` (schema)
- `app/lib/photo_tagger/uploaders/image_uploader.ex` (URL generation)
- `app/lib/photo_tagger_web/live/gallery_live/main.ex` (UI and event handlers)
- `app/lib/photo_tagger_web/controllers/photo_controller.ex` (upload integration)
- `app/priv/repo/migrations/20260210055910_add_original_photo_id_to_photos.exs`
- Test files with 54 new tests

**Related**: PR #129, Decisions [2026-02-12] in decisions.md, Spec in docs/specs/cross-listing.md

### [2026-02-04] Add shift-click multiselect for photo selection

**Summary**: Implemented shift-click multiselect functionality in the photo grid. When holding shift and clicking a photo, all photos between the last selected photo and the clicked photo are selected.

**Key Changes**:
- Added `last_selected_photo_id` to track the last clicked photo in socket assigns
- Modified `select_gallery_photo` event handler to capture and handle `shift_key_pressed` parameter
- Implemented `handle_shift_range_select/2` function to select photo ranges
- Implemented `expand_collapsed_groups/4` helper to include all photos from collapsed groups in the range
- Updated selection handlers to track last selected photo
- Added fallback handler for backwards compatibility

**Edge Cases Handled**:
- Falls back to normal multi-select when no last selected photo exists
- Falls back when last selected photo is not in current view
- For collapsed groups in the range, includes ALL photos from the group (not just visible representative)
- Works correctly with pagination and filtering

**Files Modified**:
- `app/lib/photo_tagger_web/live/gallery_live/main.ex`

**Related**: GitHub issue for shift-click multiselect

### [2026-02-04] Fix private folder visibility in upload dropdown

**Summary**: Fixed issue where private folders were not appearing in the photo upload page's folder dropdown, preventing uploads to private folders.

**Key Changes**:
- Updated `PhotoController.new/2` to pass `include_private: true` option to `Gallery.list_folders()`
- Added test case to verify both public and private folders appear in the upload form
- Documented bug and solution in bugs.md

**Files Modified**:
- `app/lib/photo_tagger_web/controllers/photo_controller.ex`
- `app/test/photo_tagger_web/controllers/photo_controller_test.exs`
- `docs/project_notes/bugs.md`

**Related**: Issue "Cannot upload photos to private folders: only public folders appear in upload folder dropdown"

### [0000-00-00] Template Entry - Remove When Adding Real Entries

**Summary**: Example of work completed
**Key Changes**:
- Example change 1
- Example change 2
**Files Modified**: `lib/example.ex`
**Related**: PR #0, Decision [YYYY-MM-DD]

---

## In Progress

(Nothing currently in progress)
