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
