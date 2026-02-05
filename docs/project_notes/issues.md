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
