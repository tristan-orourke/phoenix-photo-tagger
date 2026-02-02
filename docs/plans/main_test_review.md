# Test Review: GalleryLive.MainTest

## Summary

Expert review of `app/test/photo_tagger_web/live/gallery_live/main_test.exs` for correctness, thoroughness, intended behavior coverage, and missing edge cases.

---

## 1. Correctness Issues (Must Fix)

### 1.1 Atom Keys Instead of String Keys

LiveView event handlers expect string keys in params. The following locations use atom keys:

| Lines | Event | Current Code | Fix |
|-------|-------|--------------|-----|
| 518-521 | `select_gallery_group` | `%{photo_group: "group1", ctrl_key_pressed: false}` | `%{"photo_group" => "group1", "ctrl_key_pressed" => "false"}` |
| 543-546 | `select_gallery_group` | Same as above | Same fix |
| 553-556 | `select_gallery_group` | Same as above | Same fix |
| 1040 | `set_group_bulk` | `%{group: "vacation"}` | `%{"group" => "vacation"}` |
| 1250 | `change_folder` | `%{folder: "vacation"}` | `%{"folder" => "vacation"}` |
| 1269 | `change_folder` | `%{folder: ""}` | `%{"folder" => ""}` |

### 1.2 Overly Broad Assertions in Photo Selection Tests

**Multiple tests** use broad `assert html =~ "photoX.jpg"` which don't verify the photo is rendered in the **photo panel** specifically vs. just appearing anywhere (e.g., the gallery grid).

**Affected tests:**

| Lines | Test | Current Assertion | Problem |
|-------|------|-------------------|---------|
| 433 | `select_gallery_photo without ctrl` | `assert html =~ "photo1.jpg"` | photo1.jpg exists in gallery grid regardless |
| 454 | ctrl replaces selection | `assert html =~ "photo1.jpg"` | Same issue |
| 466-467 | ctrl replaces selection | `assert html =~ "photo2.jpg"` + `refute html =~ "photo1.jpg"` | **Refute will always fail** - photo1.jpg is still in gallery |

**Root cause**: The photo panel (`id="photo-section"`) renders the selected photo with a download link:
```html
<a href="..." download>photo_name.jpg</a>
```

But tests check the entire HTML, not specifically the photo panel.

**Fix**: Use element selectors to target the photo panel:
```elixir
# Instead of:
assert html =~ "photo1.jpg"
refute html =~ "photo1.jpg"  # WRONG - fails because photo still in gallery

# Use element selector to check photo panel specifically:
assert has_element?(view, "#photo-section a[download]", "photo1.jpg")
refute has_element?(view, "#photo-section a[download]", "photo1.jpg")

```

**Additional locations to check** (may have same issue):
- Line 284: `assert html =~ "photo1.jpg"` in `handle_params - photo selection`
- Lines 574-581: Regression test for sort preservation

---

## 2. Missing Tests (Group 4: UI State Toggle Events)

**Lines 638-641** contain a comment indicating Group 4 tests are missing:

```elixir
# NOTE: Tests 24-28 (Group 4) should be implemented here
```

### Required Tests:

1. **toggle_multiselect** - Currently only tested indirectly
   - Test: Toggling multiselect changes button styling/state
   - Test: Verify multiselect mode affects selection behavior

2. **toggle_collapse_groups**
   - Test: Groups collapse when toggle clicked
   - Test: Groups expand when toggled again
   - Test: Group collapse persists across page changes

3. **toggle_collapse_single_group**
   - Test: Single group collapses independently
   - Test: Other groups remain expanded
   - Test: Toggle again re-expands the group

---

## 3. Tests Not Addressing Intended Behavior

### 3.1 Skipped Test (Line 387-407)
The scroll_to_top test is marked `@tag :skip` with inconsistent formatting and a note saying push_event is hard to verify. This leaves scroll behavior untested.

**Recommendation**: Either implement proper scroll testing using JS hooks or document why scroll testing is acceptable to skip.

### 3.2 Weak Bulk Tag Removal Assertion (Line 791)
```elixir
refute html =~ ~r/phx-submit="remove_tag_bulk"[^>]*>.*?value="remove-me"/s
```
This regex is complex and may have false positives. A tag could be in the global tag list but not in the removable section.

**Better approach**: Check specifically within the multi-select panel's "Shared tags" section.

### 3.3 Integer vs String in photo_id params
Some tests like `add_tag` (line 655) pass `photo_id` as integer:
```elixir
render_click(view, "add_tag", %{"photo_id" => photo.id, "tag" => "landscape"})
```
While the handler may coerce this, it doesn't match real browser behavior where all values are strings. Should use `to_string(photo.id)` for consistency.

---

## 4. Missing Edge Cases

### 4.1 Error Handling
- [ ] Adding a tag that already exists on a photo (idempotent?)
- [ ] Removing a tag that doesn't exist on a photo
- [ ] Selecting a non-existent photo ID
- [ ] Navigating to a non-existent folder
- [ ] Invalid page numbers (pg=0, pg=-1, pg=999999)
- [ ] Invalid zoom levels (extreme values)

### 4.2 Empty/Null Conditions
- [ ] `add_tag_bulk` with empty selection
- [ ] `remove_tag_bulk` with empty selection
- [ ] `delete_photo_bulk` with empty selection
- [ ] `form_group_from_selected` with empty selection
- [ ] `set_group_bulk` with empty selection
- [ ] Empty tag name in `add_tag`
- [ ] Whitespace-only tag name

### 4.3 Boundary Conditions
- [ ] Pagination with exactly `page_size` items (edge of page)
- [ ] Selecting exactly all photos on current page
- [ ] Maximum zoom level behavior
- [ ] Minimum zoom level behavior
- [ ] First/last page navigation

### 4.4 Special Characters
- [ ] Tags with special characters (spaces, unicode, emoji)
- [ ] Folder names with special characters
- [ ] Photo names with special characters

### 4.5 State Consistency
- [ ] Multiselect selection persists through tag filter changes
- [ ] Selection cleared when changing folders
- [ ] Zoom level persists through folder navigation

---

## 5. Test Organization Observations

### Positive Aspects
- Good grouping by functionality (12 groups)
- Regression tests clearly labeled with `REGRESSION:` prefix
- Helper functions reduce duplication
- Async mode properly set to true

### Areas for Improvement
- Helper functions at top (lines 20-82) could be in a separate support module
- Some tests create 150 photos for pagination - consider shared setup
- Group 4 is completely missing despite having a placeholder

---

## 6. Recommended Fixes (Priority Order)

### High Priority (Tests Will Fail)
1. Fix atom keys → string keys (6 locations)
2. **Fix overly broad photo selection assertions** - especially line 467 `refute` which will always fail since photo appears in gallery grid
3. Fix integer → string for photo_id values

### Medium Priority (Missing Coverage)
4. Implement Group 4 tests (toggle events)
5. Add error handling tests
6. Add empty selection edge cases

### Low Priority (Improvements)
7. Remove or implement skipped scroll test
8. Add special character tests
9. Add boundary condition tests

---

## 7. Implementation Plan

### Phase 1: Fix Correctness Issues
1. Update all 6 locations with atom keys to use string keys
2. **Fix overly broad photo selection assertions:**
   - Line 433: Use `has_element?(view, "#photo-section a[download]", "photo1.jpg")`
   - Line 454: Same fix
   - Line 466-467: Use `has_element?` for both assert and refute
   - Line 284: Check if same issue applies
   - Lines 574-581: Check regression tests for same issue
3. Ensure all `photo_id` values use `to_string(photo.id)`

### Phase 2: Add Missing Group 4 Tests
```elixir
describe "toggle_multiselect event" do
  test "enables multi-selection mode", %{conn: conn} do
    # ...
  end

  test "disables multi-selection mode when toggled again", %{conn: conn} do
    # ...
  end
end

describe "toggle_collapse_groups event" do
  test "collapses all groups", %{conn: conn} do
    # ...
  end

  test "expands all groups when toggled again", %{conn: conn} do
    # ...
  end
end

describe "toggle_collapse_single_group event" do
  test "collapses individual group", %{conn: conn} do
    # ...
  end
end
```

### Phase 3: Add Edge Case Tests
Add describe blocks for:
- Error handling scenarios
- Empty selection scenarios
- Boundary conditions

---

## 8. Verification

After fixes:
```bash
docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/main_test.exs
```

Expected: All tests pass, increased coverage for edge cases.
