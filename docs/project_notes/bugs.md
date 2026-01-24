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

### [2026-01-24] Gallery.get_photo!/1 raises KeyError instead of Ecto.NoResultsError for private photos

**Symptoms**: When attempting to fetch a private photo without `include_private: true` flag, the function raises `KeyError` instead of the expected `Ecto.NoResultsError`
**Root Cause**: The function raises a bare `Ecto.NoResultsError` without the required `:queryable` argument. Ecto's exception handling code then tries to access a missing key, causing a `KeyError`
**Solution**: Not yet fixed - test currently expects `KeyError` to match actual behavior
**Files Affected**: `lib/photo_tagger/gallery.ex:310`
**Discovered In**: Phase 1 & Phase 2 testing (test/photo_tagger/gallery_test.exs, test/photo_tagger/gallery_access_control_test.exs)

### [2026-01-24] reorder_photos_for_insert/3 returns incompatible value for Ecto.Multi

**Symptoms**: When reordering photos during insertion, `Ecto.Multi` callbacks fail because the function returns `{count, nil}` instead of `{:ok, value}`
**Root Cause**: The function uses `Repo.update_all/2` which returns `{count, nil}`, but `Ecto.Multi` expects callbacks to return `{:ok, result}` or `{:error, reason}` tuples
**Solution**: Not yet fixed - test is currently skipped with `@tag :skip`
**Files Affected**: `lib/photo_tagger/gallery.ex:365-390`
**Discovered In**: Phase 1 testing (test/photo_tagger/gallery_test.exs:407)

### [2026-01-24] Gallery.update_photo/2 file rename fails when transformed versions don't exist

**Symptoms**: When renaming a photo that was created with mocked fixtures (no actual files), the file rename operation fails because Waffle-generated transformed versions (.webp files for thumb, web_md, web_lg) don't exist
**Root Cause**: The photo rename logic attempts to rename all image versions (original + transformed), but mocked fixtures only simulate the original file in the database without creating the actual transformed files on disk
**Solution**: Not yet fixed - currently worked around by only testing renames with photos created using `photo_fixture_with_files/1`
**Files Affected**: `lib/photo_tagger/gallery.ex` (update_photo function), `lib/photo_tagger/uploaders/image_uploader.ex`
**Discovered In**: Phase 1 testing (test/photo_tagger/gallery_test.exs)

---

## Resolved Bugs

### [0000-00-00] Template Entry - Remove When Adding Real Bugs

**Symptoms**: Example of what the bug looked like to users
**Root Cause**: Example of the underlying cause
**Solution**: Example of how it was resolved
**Files Changed**: `lib/example.ex`, `lib/example_web/live/example_live.ex`
**Related Issues**: #0
