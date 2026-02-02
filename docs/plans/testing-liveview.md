# Phase 6: LiveView Tests Implementation Plan

## Overview

This plan covers implementing comprehensive tests for the main gallery LiveView (`main.ex`) and drift LiveView (`drift.ex`). These are the most complex tests in the suite, requiring understanding of Phoenix LiveView testing patterns, event handling, and state management.

## Critical Files

### Files to Create
- `test/photo_tagger_web/live/gallery_live/main_test.exs` - Main gallery LiveView tests (~63 tests)
- `test/photo_tagger_web/live/gallery_live/drift_test.exs` - Drift/carousel mode tests (~5 tests)

### Files to Reference
- `lib/photo_tagger_web/live/gallery_live/main.ex` - LiveView implementation
- `lib/photo_tagger_web/live/gallery_live/drift.ex` - Drift mode implementation
- `test/support/fixtures/gallery_fixtures.ex` - Fixture functions (from Phase 0)
- `test/support/temp_file_helper.ex` - File helpers (from Phase 0)
- `test/support/conn_case.ex` - Phoenix test case with LiveView support

## Implementation Strategy

### Test Setup Patterns

**Pattern 1: Mocked Fixtures (Default - Use for Most Tests)**
```elixir
setup %{conn: conn} do
  # No filesystem operations needed for most LiveView tests
  folder = folder_fixture()
  photo1 = photo_fixture(%{folder_id: folder.id})
  photo2 = photo_fixture(%{folder_id: folder.id})
  tag = tag_fixture()

  {:ok, conn: conn, folder: folder, photo1: photo1, photo2: photo2, tag: tag}
end
```

**Pattern 2: Real Files (Only for Photo Creation/Deletion Flow Tests)**
```elixir
setup %{conn: conn} do
  temp_dir = TempFileHelper.setup_temp_storage(%{})
  folder = folder_fixture_with_files(%{temp_dir: temp_dir})
  photo = photo_fixture_with_files(%{folder_id: folder.id, temp_dir: temp_dir})

  {:ok, conn: conn, temp_dir: temp_dir, folder: folder, photo: photo}
end
```

### LiveView Testing Patterns

**Mounting a LiveView:**
```elixir
{:ok, view, html} = live(conn, "/admin/folders/#{folder.name}")
```

**Triggering Events:**
```elixir
# Click events
html = render_click(view, "event_name", %{param: value})

# Change events (forms)
html = render_change(view, "event_name", %{param: value})

# Submit events
html = render_submit(view, "event_name", %{param: value})
```

**Asserting State:**
```elixir
# Check assigns
assert view.assigns.some_value == expected

# Check rendered HTML
assert html =~ "expected text"
assert has_element?(view, "#element-id")
assert has_element?(view, "button", "Button Text")
```

**Testing Navigation:**
```elixir
# Follow push_patch navigation
assert_patch(view, "/expected/path")

# Manual navigation
{:ok, view, html} = live(conn, "/some/path?query=param")
```

## Test Group Breakdown

### Group 1: Mounting and Initial State (5 tests)

**Purpose:** Verify LiveView initializes correctly with proper defaults and access control.

**Setup:** Mocked fixtures

**Tests:**
1. `test "mount/3 sets is_admin to false for public action"`
   - Mount with `live_action: :public`
   - Assert `view.assigns.is_admin == false`
   - Assert layout uses `:app` instead of `:admin`

2. `test "mount/3 sets is_admin to true for admin actions"`
   - Mount with `live_action: :index`
   - Assert `view.assigns.is_admin == true`
   - Assert layout uses `:admin`

3. `test "mount/3 loads all folders and tags"`
   - Create 3 folders (2 public, 1 private)
   - Create 3 tags
   - Mount as admin
   - Assert `length(view.assigns.all_folders) == 3`
   - Assert `length(view.assigns.all_tags) == 3`
   - Mount as public
   - Assert `length(view.assigns.all_folders) == 2` (public only)

4. `test "mount/3 sets default zoom_level, multiselect_active, collapse_groups"`
   - Mount LiveView
   - Assert `view.assigns.zoom_level == 0`
   - Assert `view.assigns.multiselect_active == false`
   - Assert `view.assigns.collapse_groups == true`

5. `test "mount/3 uses admin layout for admin routes, app layout for public"`
   - This is partly tested in #1 and #2, but verify the actual `:layout` socket assign

---

### Group 2: Handle Params and URL Routing (10 tests)

**Purpose:** Verify URL parameter parsing, state expansion, and photo filtering logic.

**Setup:** Mocked fixtures with multiple photos and tags

**Tests:**

6. `test "handle_params with folder param loads folder photos"`
   - Create folder with 3 photos
   - Create another folder with 2 photos
   - Navigate to `/admin/folders/#{folder.name}`
   - Assert `length(view.assigns.filtered_photos) == 3`
   - Assert all photos belong to correct folder

7. `test "handle_params with query_tags filters photos by tags"`
   - Create photo1 with tag1, photo2 with tag1+tag2, photo3 with tag2
   - Navigate to `/admin/photos?query_tags[]=#{tag1.name}`
   - Assert filtered_photos contains photo1 and photo2, not photo3

8. `test "handle_params with exclude_tags filters out photos"`
   - Create photo1 with tag1, photo2 with tag2, photo3 with no tags
   - Navigate to `/admin/photos?exclude_tags[]=#{tag1.name}`
   - Assert filtered_photos contains photo2 and photo3, not photo1

9. `test "handle_params with photo_id selects photo"`
   - Create folder with 2 photos
   - Navigate to `/admin/folders/#{folder.name}/photos/#{photo1.id}`
   - Assert `view.assigns.selected_photo_ids == [photo1.id]`
   - Assert HTML contains photo detail section

10. `test "handle_params with selected_photos selects multiple photos"`
    - Create 3 photos
    - Navigate to `/admin/photos?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}`
    - Assert `view.assigns.selected_photo_ids == [photo1.id, photo2.id]`
    - Assert multiselect mode active

11. `test "handle_params with sort param sets sort order"`
    - Navigate to `/admin/photos?sort=manual`
    - Assert `view.assigns.sort == :manual`
    - Navigate to `/admin/photos` (no sort param)
    - Assert `view.assigns.sort == :date` (default)

12. `test "handle_params with pg param sets page number"`
    - Create 150 photos (exceeds page size of 100)
    - Navigate to `/admin/photos?pg=2`
    - Assert `view.assigns.pg == 2`
    - Assert correct photos shown

13. `test "handle_params with pg_size param sets page size"`
    - Navigate to `/admin/photos?pg_size=50`
    - Assert `view.assigns.pg_size == 50`

14. `test "handle_params reuses cached filtered_photos when params unchanged"`
    - Navigate to folder
    - Capture `view.assigns.filtered_photos` (reference)
    - Trigger non-filtering event (e.g., zoom)
    - Verify `view.assigns.filtered_photos` is same reference (not re-queried)

15. `test "handle_params triggers scroll_to_top events when relevant params change"`
    - This is tricky - may need to inspect push_event calls
    - Navigate to folder, then change folder
    - Verify scroll events pushed (might require mocking or inspecting socket)

---

### Group 3: Photo Selection Events (8 tests - includes regression tests)

**Purpose:** Test single/multi photo selection logic and verify settings preservation.

**Setup:** Mocked fixtures

**Tests:**

16. `test "select_gallery_photo without ctrl selects single photo"`
    - Mount view with folder
    - Render click: `select_gallery_photo` with `%{photo_id: photo1.id, ctrl_key_pressed: false}`
    - Assert `view.assigns.selected_photo_ids == [photo1.id]`
    - Assert URL patched to include photo_id

17. `test "select_gallery_photo with ctrl adds to selection in multiselect mode"`
    - Mount view
    - Select photo1 (establishes selection)
    - Trigger `toggle_multiselect`
    - Select photo2 with ctrl
    - Assert `view.assigns.selected_photo_ids` contains both photo1 and photo2

18. `test "select_gallery_photo with ctrl replaces selection when multiselect inactive"`
    - Select photo1
    - Select photo2 with ctrl (but multiselect_active is false)
    - Assert `view.assigns.selected_photo_ids == [photo2.id]` (replaced, not added)

19. `test "select_gallery_group selects all photos in group"`
    - Create 3 photos with same group name
    - Create 1 photo with different group
    - Click group: `select_gallery_group` with `%{photo_group: "group1", ctrl_key_pressed: false}`
    - Assert all 3 photos in group1 selected

20. `test "select_gallery_group in multiselect mode toggles group selection"`
    - Create group with 3 photos
    - Enable multiselect
    - Select group (all 3 selected)
    - Select group again (all 3 deselected)

21. `test "REGRESSION: selecting photo preserves sort order"`
    - Navigate to `/admin/photos?sort=manual`
    - Assert `view.assigns.sort == :manual`
    - Select photo
    - Assert `view.assigns.sort == :manual` (unchanged)

22. `test "REGRESSION: selecting photo preserves zoom level"`
    - Trigger `zoom_in` twice
    - Assert `view.assigns.zoom_level == 2`
    - Select photo
    - Assert `view.assigns.zoom_level == 2` (unchanged)

23. `test "REGRESSION: selecting photo preserves page number"`
    - Navigate to page 2
    - Assert `view.assigns.pg == 2`
    - Select photo
    - Assert `view.assigns.pg == 2` (unchanged)

---

### Group 4: UI State Toggle Events (5 tests)

**Purpose:** Test view control toggles (multiselect, collapse, zoom).

**Setup:** Mocked fixtures

**Tests:**

24. `test "toggle_multiselect toggles multiselect_active"`
    - Assert `view.assigns.multiselect_active == false`
    - Render click: `toggle_multiselect`
    - Assert `view.assigns.multiselect_active == true`
    - Click again
    - Assert `view.assigns.multiselect_active == false`

25. `test "toggle_collapse_groups toggles collapse_groups"`
    - Assert `view.assigns.collapse_groups == true` (default)
    - Render click: `toggle_collapse_groups`
    - Assert `view.assigns.collapse_groups == false`

26. `test "toggle_collapse_groups resets collapse_group_exceptions"`
    - Manually set some exceptions in assigns
    - Toggle collapse groups
    - Assert `view.assigns.collapse_group_exceptions == %{}`

27. `test "toggle_collapse_single_group updates exceptions map"`
    - Create photos with group "2024-01-15"
    - Assert collapse_groups is true
    - Click single group collapse: `toggle_collapse_single_group` with `%{photo_group: "2024-01-15"}`
    - Assert `view.assigns.collapse_group_exceptions["2024-01-15"] == false`

28. `test "REGRESSION: toggling multiselect preserves other view settings"`
    - Set sort to manual, zoom to 3, page to 2
    - Toggle multiselect
    - Assert sort, zoom, page all preserved

---

### Group 5: Tag Management Events (8 tests)

**Purpose:** Test adding/removing tags from single and multiple photos.

**Setup:** Mocked fixtures

**Tests:**

29. `test "add_tag adds tag to photo and refreshes"`
    - Select photo
    - Render click: `add_tag` with `%{photo_id: photo.id, tag: "landscape"}`
    - Reload photo from DB
    - Assert "landscape" in photo's tags
    - Assert `view.assigns.filtered_photos` updated (photo now has tag)

30. `test "add_tag creates new tag if it doesn't exist"`
    - Tag count before
    - Add tag "newtag" to photo
    - Assert tag created in DB
    - Assert photo has tag

31. `test "remove_tag removes tag from photo and refreshes"`
    - Add tag to photo
    - Remove tag via event
    - Reload photo
    - Assert tag removed

32. `test "add_tag_bulk adds tag to all selected photos"`
    - Select photo1 and photo2 (multiselect)
    - Render click: `add_tag_bulk` with `%{tag: "bulk-tag"}`
    - Reload both photos
    - Assert both have "bulk-tag"

33. `test "remove_tag_bulk removes tag from all selected photos"`
    - Add tag to photo1 and photo2
    - Select both
    - Remove tag via bulk event
    - Assert tag removed from both

34. `test "toggle_tag adds tag to query when not present"`
    - Mount view without tag filters
    - Render click: `toggle_tag` with `%{tag: "sunset"}`
    - Assert `view.assigns.tags` includes "sunset"
    - Assert URL patched to include query_tags[]=sunset

35. `test "toggle_tag removes tag from query when present"`
    - Navigate with tag filter
    - Toggle same tag
    - Assert tag removed from query
    - Assert URL updated

36. `test "toggle_exclude_tag adds tag to exclude list"`
    - Render click: `toggle_exclude_tag` with `%{tag: "blur"}`
    - Assert `view.assigns.exclude_tags` includes "blur"
    - Assert URL includes exclude_tags[]=blur

---

### Group 6: Photo Update and Delete Events (6 tests - includes regression tests)

**Purpose:** Test photo mutations and verify gallery refresh.

**Setup:** Mocked fixtures (except delete tests which might need real files)

**Tests:**

37. `test "update_photo updates photo and shows flash"`
    - Select photo
    - Render click: `update_photo` with `%{photo_id: photo.id, photo: %{name: "new_name.jpg"}}`
    - Assert flash message shown
    - Reload photo
    - Assert name changed

38. `test "update_photo with invalid data shows error flash"`
    - Select photo
    - Update with invalid data (e.g., blank name)
    - Assert error flash shown
    - Assert photo unchanged in DB

39. `test "REGRESSION: update_photo refreshes gallery panel"`
    - Select photo with name "old.jpg"
    - Update name to "new.jpg"
    - Assert `view.assigns.filtered_photos` contains photo with "new.jpg"
    - Assert "old.jpg" not in filtered_photos

40. `test "REGRESSION: update_photo refreshes selected photo in photo panel"`
    - Select photo
    - Update photo description
    - Assert `view.assigns.selected_photos` reflects new description
    - Assert rendered HTML shows new description

41. `test "delete_photo removes photo and redirects"`
    - Create 2 photos in folder
    - Select photo1
    - Render click: `delete_photo` with `%{photo_id: photo1.id}`
    - Assert photo deleted from DB
    - Assert redirected/patched to folder without photo_id
    - Assert flash message shown

42. `test "delete_photo_bulk deletes all selected photos"`
    - Create 3 photos
    - Select all 3 (multiselect)
    - Render click: `delete_photo_bulk`
    - Assert all 3 deleted from DB
    - Assert view redirects/clears selection

---

### Group 7: Group Management Events (3 tests)

**Purpose:** Test bulk group assignment and formation.

**Setup:** Mocked fixtures

**Tests:**

43. `test "set_group_bulk sets group for all selected photos"`
    - Create 3 photos with different groups
    - Select all 3
    - Render click: `set_group_bulk` with `%{group: "vacation"}`
    - Reload photos
    - Assert all have group "vacation"

44. `test "form_group_from_selected creates new group from timestamp"`
    - Create 3 photos without groups
    - Select all 3
    - Render click: `form_group_from_selected`
    - Reload photos
    - Assert all share same group (timestamp-based)

45. `test "form_group_from_selected reuses existing group if all photos share one"`
    - Create 3 photos with group "existing-group"
    - Select all 3
    - Form group
    - Reload photos
    - Assert all still have "existing-group" (not new group)

---

### Group 8: View Settings Events (5 tests - includes regression tests)

**Purpose:** Test zoom and sort controls.

**Setup:** Mocked fixtures

**Tests:**

46. `test "zoom_in increases zoom_level"`
    - Assert `view.assigns.zoom_level == 0`
    - Render click: `zoom_in`
    - Assert `view.assigns.zoom_level == 1`

47. `test "zoom_out decreases zoom_level"`
    - Trigger zoom_in to set level to 1
    - Render click: `zoom_out`
    - Assert `view.assigns.zoom_level == 0`

48. `test "zoom_in and zoom_out clamp between -9 and 9"`
    - Zoom in 15 times
    - Assert `view.assigns.zoom_level == 9` (clamped)
    - Zoom out 25 times
    - Assert `view.assigns.zoom_level == -9` (clamped)

49. `test "change_sort updates sort order and triggers URL update"`
    - Assert default sort is :date
    - Render click: `change_sort` with `%{sort: "manual"}`
    - Assert `view.assigns.sort == :manual`
    - Assert URL includes ?sort=manual

50. `test "REGRESSION: change_sort preserves other view settings"`
    - Set zoom to 3, page to 2, enable multiselect
    - Change sort
    - Assert zoom, page, multiselect all preserved

---

### Group 9: Folder Navigation Events (2 tests)

**Purpose:** Test folder selection and navigation.

**Setup:** Mocked fixtures

**Tests:**

51. `test "change_folder navigates to folder"`
    - Create folder "vacation"
    - Render click: `change_folder` with `%{folder: "vacation"}`
    - Assert patched to `/admin/folders/vacation`
    - Assert `view.assigns.folder.name == "vacation"`

52. `test "change_folder with empty string navigates to all folders"`
    - Start in folder view
    - Render click: `change_folder` with `%{folder: ""}`
    - Assert patched to `/admin/photos`
    - Assert `view.assigns.folder == nil`

---

### Group 10: Pagination Events (2 tests)

**Purpose:** Test page navigation.

**Setup:** Mocked fixtures with 150 photos (exceeds page size)

**Tests:**

53. `test "change_page updates page number"`
    - Create 150 photos
    - Navigate to page 1 (default)
    - Render click: `change_page` with `%{page: 2}`
    - Assert `view.assigns.pg == 2`
    - Assert URL includes ?pg=2

54. `test "change_page triggers scroll to top"`
    - Change page
    - Verify scroll event pushed (may need to inspect socket's push_event history)

---

### Group 11: Component Rendering (6 tests)

**Purpose:** Test that components render correctly with proper data.

**Setup:** Mocked fixtures

**Tests:**

55. `test "gallery_header renders breadcrumb navigation"`
    - Navigate to folder with tag filters
    - Assert HTML contains folder name
    - Assert HTML contains tag names in breadcrumb

56. `test "gallery_header renders sort dropdown"`
    - Render view
    - Assert has_element?(view, "select[name='sort']")
    - Assert dropdown has "Date" and "Manual" options

57. `test "gallery_header renders view controls (zoom, multiselect, collapse)"`
    - Assert has_element?(view, "button", "Zoom In")
    - Assert has_element?(view, "button", "Zoom Out")
    - Assert has_element?(view, "button") with multiselect text
    - Assert has_element?(view, "button") with collapse text

58. `test "gallery renders photos with correct zoom level"`
    - Set zoom to 3
    - Render gallery
    - Assert grid container has correct CSS class reflecting zoom level

59. `test "gallery renders pagination when needed"`
    - Create 150 photos
    - Navigate to folder
    - Assert has_element?(view, ".pagination") or similar
    - Assert page links rendered

60. `test "photo panel renders selected photo details"`
    - Select photo with name, description, tags
    - Assert HTML contains photo name
    - Assert HTML contains description
    - Assert HTML contains tag names

---

### Group 12: Utility Function Tests (3 tests)

**Purpose:** Test helper functions used in LiveView.

**Setup:** Unit tests (no LiveView mount needed)

**Tests:**

61. `test "member_by_id?/2 returns true when item in list"`
    - Create list of photo structs
    - Call `member_by_id?([%{id: 1}, %{id: 2}], 1)`
    - Assert true

62. `test "member_by_id?/2 returns false when item not in list"`
    - Call `member_by_id?([%{id: 1}, %{id: 2}], 3)`
    - Assert false

63. `test "simplify_photo/1 extracts only needed fields"`
    - Create full photo struct with all fields
    - Call `simplify_photo(photo)`
    - Assert result only has :id, :name, :group, :image, :folder

---

## Drift LiveView Tests (5 tests)

**File:** `test/photo_tagger_web/live/gallery_live/drift_test.exs`

**Purpose:** Test carousel/slideshow mode

**Setup:** Mocked fixtures

**Tests:**

1. `test "mount/3 loads initial photo and starts timer"`
   - Create folder with 5 photos
   - Mount drift view: `live(conn, "/drift/#{folder.name}")`
   - Assert `view.assigns.current_photo` is one of the photos
   - Assert timer reference exists in assigns

2. `test "mount/3 selects random photo based on weights"`
   - This tests WeightedList integration
   - Create photos with various tag frequencies
   - Mount drift view multiple times
   - Verify weighted selection (statistical test with many iterations)

3. `test "handle_info :next_photo advances to next photo"`
   - Mount drift view
   - Capture current photo
   - Send `:next_photo` message to process
   - Assert `view.assigns.current_photo` changed

4. `test "drift mode respects public/private access control"`
   - Create public and private photos
   - Mount drift view in public mode
   - Verify only public photos appear
   - Mount in admin mode
   - Verify all photos can appear

5. `test "drift mode navigates between photos in folder"`
   - Create folder with 3 photos
   - Create another folder with 2 photos
   - Mount drift for folder1
   - Verify only folder1 photos shown in rotation

---

## Implementation Order

1. **Setup infrastructure** (import statements, module setup)
2. **Group 1-2:** Basic mounting and URL routing (foundation)
3. **Group 3-4:** Selection and UI toggles (core interactions)
4. **Group 5-6:** Tag and photo management (CRUD operations)
5. **Group 7-10:** Bulk operations, sorting, navigation
6. **Group 11-12:** Rendering and utilities
7. **Drift tests:** Separate file for drift mode

## Testing Challenges & Solutions

### Challenge 1: Scroll Events
**Issue:** `push_event` for scrolling is hard to verify in tests
**Solution:** Either skip these assertions or mock the socket to capture push_event calls

### Challenge 2: Caching Verification
**Issue:** Hard to verify that queries are cached vs re-executed
**Solution:** Use reference equality on assigns (`===`) or add logging/instrumentation

### Challenge 3: Event Delegation
**Issue:** Some events are handled by child components
**Solution:** Use `phx-target` in render_click to specify component target

### Challenge 4: Multiselect Mode Complexity
**Issue:** Selection behavior changes based on multiselect_active and ctrl key
**Solution:** Test all combinations with clear setup for each scenario

## Verification Strategy

After implementing all tests:

1. **Run full suite:** `mix test test/photo_tagger_web/live/gallery_live/`
2. **Run individual groups:** `mix test test/photo_tagger_web/live/gallery_live/main_test.exs:line`
3. **Check coverage:** Ensure all event handlers are covered
4. **Regression verification:** Manually verify the two known bugs don't reoccur
5. **Integration test:** Mount LiveView in browser and manually test interactions

## Success Criteria

- All 63 main LiveView tests pass
- All 5 drift LiveView tests pass
- Test coverage of all handle_event callbacks
- Test coverage of all handle_params scenarios
- Regression tests prevent known bugs from returning
- Tests run in <10 seconds (mocked fixtures are fast)
- No flaky tests due to timing or race conditions

## Notes

- **Use mocked fixtures by default** - Only use real files for tests that explicitly verify file operations
- **Test behavior, not implementation** - Focus on observable state changes and HTML output
- **Keep tests readable** - Use descriptive test names and clear assertions
- **Regression tests are critical** - Mark them clearly with "REGRESSION:" prefix for visibility
