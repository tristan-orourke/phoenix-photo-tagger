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

(No active bugs currently logged)

---

## Resolved Bugs

### [2026-02-04] Private folders not visible in upload dropdown

**Symptoms**: When uploading photos, only public folders appeared in the folder dropdown. Users could not select private folders for upload even if they had access.

**Root Cause**: `PhotoController.new/2` called `Gallery.list_folders()` without the `include_private: true` option. The Gallery context's `only_public_folders_unless_forced/2` helper filters out private folders by default when this option is not provided.

**Solution**: Updated `PhotoController.new/2` to pass `include_private: true` to `Gallery.list_folders()` call, ensuring both public and private folders appear in the dropdown.

**Files Changed**: 
- `app/lib/photo_tagger_web/controllers/photo_controller.ex`
- `app/test/photo_tagger_web/controllers/photo_controller_test.exs` (added test for verification)

**Related Issues**: Issue "Cannot upload photos to private folders: only public folders appear in upload folder dropdown"

### [0000-00-00] Template Entry - Remove When Adding Real Bugs

**Symptoms**: Example of what the bug looked like to users
**Root Cause**: Example of the underlying cause
**Solution**: Example of how it was resolved
**Files Changed**: `lib/example.ex`, `lib/example_web/live/example_live.ex`
**Related Issues**: #0
