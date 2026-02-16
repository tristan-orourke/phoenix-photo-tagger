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

(None)

---

## Resolved Bugs

### [2026-02-16] Uploaded photos assigned incorrect manual_order (always 1)

**Symptoms**: When uploading new photos to a folder that already contained photos, the new photos were being assigned `manual_order = 1` instead of the next sequential number (e.g., if the folder had 3 photos, new uploads should get orders 4, 5, 6, but were all getting 1). This caused confusion in photo ordering and potential conflicts.

**Root Cause**: The `Gallery.get_next_manual_order/1` function receives `folder_id` as a string from the form parameters (e.g., `"5"`), but was using it directly in an Ecto query where `folder_id` is an integer database column. The query `where: p.folder_id == ^"5"` doesn't match integer column values, so `max(manual_order)` returned `nil`, causing the function to always return `1`.

**Solution**: Converted string `folder_id` to integer in `create_photo/1` before calling `get_next_manual_order/1`. This handles type conversion at the system boundary (where form params enter) rather than inside the helper function. Made `get_next_manual_order/1` only accept integers using a guard clause (`when is_integer(folder_id)`), making its contract clearer and consistent with how other callers (e.g., `create_cross_listing`) handle the conversion.

**Files Changed**:
- `app/lib/photo_tagger/gallery.ex` - Added type conversion in `create_photo/1`; simplified `get_next_manual_order/1` to only accept integers
- `app/test/photo_tagger/gallery_test.exs` - Integration test through `create_photo` with string folder_id verifies the fix

**Testing**: Existing integration test verifies that `create_photo` correctly handles string folder_id from form params and assigns sequential manual_order values.

**Related Issues**: Issue "uploaded photos should get a manual order number at the end of their folder"

### [2026-02-04] Private folders not visible in upload dropdown

**Symptoms**: When uploading photos, only public folders appeared in the folder dropdown. Users could not select private folders for upload even if they had access.

**Root Cause**: `PhotoController.new/2` called `Gallery.list_folders()` without the `include_private: true` option. The Gallery context's `only_public_folders_unless_forced/2` helper filters out private folders by default when this option is not provided.

**Solution**: Updated `PhotoController.new/2` to pass `include_private: true` to `Gallery.list_folders()` call, ensuring both public and private folders appear in the dropdown.

**Files Changed**:
- `app/lib/photo_tagger_web/controllers/photo_controller.ex`
- `app/test/photo_tagger_web/controllers/photo_controller_test.exs` (added test for verification)

**Related Issues**: Issue "Cannot upload photos to private folders: only public folders appear in upload folder dropdown"

### [2026-01-30] PhotoController edit view raises Protocol.UndefinedError for folder field

**Symptoms**: When accessing the edit view for a photo (e.g., `/admin/photos/:id/edit`), the application crashes with `Protocol.UndefinedError: protocol Phoenix.HTML.Safe not implemented for type PhotoTagger.Gallery.Folder (a struct)`
**Root Cause**: The edit form template at `lib/photo_tagger_web/controllers/photo_html/edit_photo_form.html.heex:6` incorrectly used `field={f[:folder]}` which tries to render the entire Folder struct. Since Photo has a `belongs_to :folder` association, the database field is actually `folder_id`, not `folder`. Phoenix.HTML.Safe protocol is not implemented for structs, so rendering fails. Additionally, the controller didn't pass the folders list for the select dropdown
**Solution**: Changed form field from `f[:folder]` to `f[:folder_id]` with a select dropdown matching the pattern in `new_photo_form.html.heex`. Updated controller to fetch and pass folders list to the view. Updated `edit.html.heex` to pass `folders={@folders}` to the form component
**Files Changed**: `app/lib/photo_tagger_web/controllers/photo_controller.ex`, `app/lib/photo_tagger_web/controllers/photo_html/edit_photo_form.html.heex`, `app/lib/photo_tagger_web/controllers/photo_html/edit.html.heex`
**Discovered In**: Manual testing / user-reported bug

### [2026-01-30] PhotoController edit action raises Ecto.NoResultsError for private photos

**Symptoms**: When attempting to access the edit view for a private photo (e.g., `/admin/photos/:id/edit`), the controller raises `Ecto.NoResultsError` and crashes
**Root Cause**: Line 88 in `lib/photo_tagger_web/controllers/photo_controller.ex` calls `Gallery.get_photo!(id)` without the `include_private: true` option. The `Gallery.get_photo!/1` function filters out private photos by default, causing it to raise an error even for valid photo IDs in private folders
**Solution**: Changed `Gallery.get_photo!(id)` to `Gallery.get_photo!(id, include_private: true)` since admin controllers should have access to all photos regardless of privacy status
**Files Changed**: `app/lib/photo_tagger_web/controllers/photo_controller.ex`
**Discovered In**: Manual testing / code review

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
