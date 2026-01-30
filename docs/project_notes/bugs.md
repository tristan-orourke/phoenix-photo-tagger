# Bug Log

Track bugs with root causes and solutions for future reference.

## Format

```markdown
### [YYYY-MM-DD] Brief Bug Description

**Symptoms**: What was observed
**Root Cause**: Why it happened
**Solution**: How it was fixed
**Files Changed**: List of modified files
**Related Issues**: #issue-number (if applicable)
```

---

## Active Bugs

_(None at this time)_

---

## Resolved Bugs

### [2026-01-30] FolderController string interpolation causes Protocol.UndefinedError

**Symptoms**: When creating a folder with a duplicate name, the application crashes with `Protocol.UndefinedError: protocol String.Chars not implemented for type Ecto.Changeset`
**Root Cause**: Error handlers in FolderController (lines 20-26, 45-51, 64-70, 83-89) attempt to convert `Ecto.Changeset` to string via interpolation (`"Error #{failed_value}"`), but `String.Chars` protocol is not implemented for changesets
**Solution**: Add pattern matching to handle `Ecto.Changeset` errors separately - extract human-readable error from changeset.errors field instead of directly interpolating the struct
**Files Changed**: `lib/photo_tagger_web/controllers/folder_controller.ex`, `test/photo_tagger_web/controllers/folder_controller_test.exs`
**Discovered In**: Phase 5 controller testing (test/photo_tagger_web/controllers/folder_controller_test.exs:49)

### [2026-01-24] reorder_photos_for_insert/3 returns incompatible value for Ecto.Multi

**Symptoms**: When reordering photos during insertion, `Ecto.Multi` callbacks fail because the function returns `{count, nil}` instead of `{:ok, value}`
**Root Cause**: The function uses `Repo.update_all/2` which returns `{count, nil}`, but `Ecto.Multi` expects callbacks to return `{:ok, result}` or `{:error, reason}` tuples
**Solution**: Wrapped the return value in `:ok` tuple at line 398: changed from `if query, do: Repo.update_all(query, []), else: {0, nil}` to `if query, do: {:ok, Repo.update_all(query, [])}, else: {:ok, {0, nil}}`
**Files Changed**: `lib/photo_tagger/gallery.ex`, `test/photo_tagger/gallery_test.exs`
**Discovered In**: Phase 1 testing (test/photo_tagger/gallery_test.exs:652)

### [2026-01-24] Gallery.get_photo!/1 raises KeyError instead of Ecto.NoResultsError for private photos

**Symptoms**: When attempting to fetch a private photo without `include_private: true` flag, the function raises `KeyError` instead of the expected `Ecto.NoResultsError`
**Root Cause**: The function raises a bare `Ecto.NoResultsError` without the required `:queryable` argument. Ecto's exception handling code then tries to access a missing key, causing a `KeyError`
**Solution**: Changed `raise Ecto.NoResultsError` to `raise Ecto.NoResultsError, queryable: Photo` at line 310
**Files Changed**: `lib/photo_tagger/gallery.ex`, `test/photo_tagger/gallery_test.exs`, `test/photo_tagger/gallery_access_control_test.exs`
**Discovered In**: Phase 1 & Phase 2 testing (test/photo_tagger/gallery_test.exs, test/photo_tagger/gallery_access_control_test.exs)

### [2026-01-24] Gallery.update_photo/2 file rename fails with :enoent

**Symptoms**: When renaming or moving a photo, the operation fails with `:enoent` (file not found) error even when files exist on disk
**Root Cause**: The `photo_full_path/2` function in Gallery module hardcoded `.jpg` extension for transformed versions (thumb, web_md, web_lg), but Waffle actually creates these as `.webp` files. This caused the rename operation to try to rename non-existent `.jpg` files instead of the actual `.webp` files.
**Solution**: Changed `photo_full_path/2` in `lib/photo_tagger/gallery.ex:349` from `.jpg` to `.webp` for transformed versions
**Files Changed**: `lib/photo_tagger/gallery.ex`
**Discovered In**: Phase 3 testing (test/photo_tagger/gallery_file_operations_test.exs)
