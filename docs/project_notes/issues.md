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

### [2026-02-05] Add admin-only button to hide all private photos

**Summary**: Added a toggle button to the gallery header visible only to admins, which filters out all private photos when activated. The filtering is immediate and can be toggled on/off without page reload.

**Key Changes**:
- Added `hide_private_photos` state tracking in socket assigns
- Added toggle button in gallery header with eye-slash icon (admin-only)
- Implemented `toggle_hide_private_photos` event handler
- Updated photo filtering logic in `expand_state/2` to respect hide_private_photos flag
- Improved cache invalidation to track hide_private_photos state changes
- Added comprehensive test coverage for the new functionality

**Files Modified**: 
- `app/lib/photo_tagger_web/live/gallery_live/main.ex`
- `app/test/photo_tagger_web/live/gallery_live/main_test.exs`

**Related**: Issue "Add admin-only button to gallery header to hide all private photos"

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
