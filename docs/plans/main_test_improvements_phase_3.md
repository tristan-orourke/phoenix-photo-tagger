# Plan: Improve Tests Not Addressing Intended Behavior

## Overview
This plan addresses Section 3 of the test review document, focusing on three categories of tests that don't adequately verify intended behavior in `main_test.exs`.

## Background

Based on exploration of the codebase, I've identified three test quality issues:

1. **Skipped scroll_to_top test** (lines 391-411) - Can't verify `push_event` calls in Phoenix LiveView 1.0
2. **Weak bulk tag removal assertion** (line 795) - Complex regex that's hard to maintain and may have false positives
3. **Integer photo_id params** - Already fixed in previous work (lines 648, 671, 704)

## Issue 1: Skipped Scroll Test

### Current State
- Test marked with `@tag :skip`
- Comment: "We can't easily assert push_event calls in standard LiveView tests"
- The LiveView sends 3 types of scroll events via `push_event`:
  - Scroll `#photo-section` when selected photos change
  - Scroll `#tags-section` when folder changes
  - Scroll `#gallery-section` when folder or tags change
- JavaScript handler in `scrollEvents.js` receives these events and scrolls elements

### Root Cause
Phoenix LiveView 1.0.x doesn't provide `assert_push_event/3` (only available in 1.1+). Testing `push_event` calls requires:
- Upgrading to Phoenix LiveView 1.1+ (may have dependency conflicts)
- Inspecting internal socket state (fragile, depends on Phoenix internals)
- E2E browser testing (overkill for unit tests)

### Recommendation: Document & Accept Limitation

**Rationale:**
- The scroll functionality works correctly in manual testing
- The condition logic that determines when to scroll IS tested via state changes
- Upgrading Phoenix is a larger architectural decision
- The test plan (testing-liveview.md) already identifies this as "Challenge 1"

**Action:**
Update the skipped test comment to clearly explain:
1. Why it's skipped (Phoenix 1.0 limitation)
2. What's being tested instead (state change conditions)
3. How it's verified (manual testing)
4. What would enable the test (Phoenix 1.1+ upgrade)

## Issue 2: Weak Bulk Tag Removal Assertion

### Current State (Line 795)
```elixir
refute html =~ ~r/phx-submit="remove_tag_bulk"[^>]*>.*?value="remove-me"/s
```

**Problems:**
- Complex regex trying to match across HTML elements
- Fragile - depends on specific attribute ordering
- Hard to read and maintain
- May have false positives (tag could be elsewhere in HTML)

### HTML Structure
The multi-select panel's "Remove tags" section renders:
```heex
<:item title="Remove tags">
  <ul class="flex flex-wrap">
    <%= for tag <- (@tags_to_remove ++ @tags_in_limbo) do %>
      <li>
        <.form phx-submit="remove_tag_bulk">
          <input class="hidden" type="text" name="tag" value={tag} />
          <button type="submit">{tag}</button>
        </.form>
      </li>
    <% end %>
  </ul>
</:item>
```

### Recommendation: Add Helper Function

**Action 1:** Add a test helper function following the pattern of existing helpers:

```elixir
defp extract_removable_tags(html) do
  # Extract tag names from the multi-select panel's "Remove tags" section
  # Tags appear as hidden input values in forms with phx-submit="remove_tag_bulk"
  Regex.scan(~r/<input[^>]*class="hidden"[^>]*name="tag"[^>]*value="([^"]+)"[^>]*>/, html)
  |> Enum.map(fn [_, tag] -> tag end)
  |> Enum.uniq()
end
```

**Action 2:** Update the assertion in the test:

```elixir
# Replace line 795
refute html =~ ~r/phx-submit="remove_tag_bulk"[^>]*>.*?value="remove-me"/s

# With
removable_tags = extract_removable_tags(html)
refute "remove-me" in removable_tags
```

**Benefits:**
- Clearer intent - explicitly extracting removable tags
- More maintainable - regex focuses on one element
- Easier to debug - can inspect `removable_tags` if test fails
- Follows existing pattern (`count_selected_photos/1`, `extract_selected_tags/1`, etc.)

## Issue 3: Integer photo_id Params

### Status: ✅ Already Fixed
This issue was addressed in the previous implementation phase:
- Line 648: `add_tag` now uses `to_string(photo.id)`
- Line 671: `add_tag` now uses `to_string(photo.id)`
- Line 704: `remove_tag` now uses `to_string(photo.id)`

All `photo_id` parameters now correctly use string conversion to match real browser behavior.

## Implementation Steps

### Step 1: Update Scroll Test Documentation
**File:** `app/test/photo_tagger_web/live/gallery_live/main_test.exs`
**Lines:** 390-392

Replace:
```elixir
@tag :skip
test "triggers scroll_to_top events when relevant params change", %{conn: conn} do
```

With:
```elixir
# SKIPPED: Phoenix LiveView 1.0 doesn't provide assert_push_event/3 for testing
# push_event calls (available in 1.1+). The scroll_to_top logic is tested indirectly
# via state changes in handle_params tests. Scroll behavior verified via manual testing.
# To enable: Upgrade to Phoenix LiveView 1.1+ and use assert_push_event(socket, "scroll_to_top", %{selector: ...})
@tag :skip
test "triggers scroll_to_top events when relevant params change", %{conn: conn} do
```

### Step 2: Add Helper Function for Removable Tags
**File:** `app/test/photo_tagger_web/live/gallery_live/main_test.exs`
**Location:** After line 82 (in the helper functions section)

Add:
```elixir
defp extract_removable_tags(html) do
  # Extract tag names from the multi-select panel's "Remove tags" section
  # Tags appear as hidden input values in forms with phx-submit="remove_tag_bulk"
  Regex.scan(~r/<input[^>]*class="hidden"[^>]*name="tag"[^>]*value="([^"]+)"[^>]*>/, html)
  |> Enum.map(fn [_, tag] -> tag end)
  |> Enum.uniq()
end
```

### Step 3: Update Bulk Tag Removal Test
**File:** `app/test/photo_tagger_web/live/gallery_live/main_test.exs`
**Line:** 795

Replace:
```elixir
# Tag should not appear in the multi-select panel's removable tags section
# The remove tags section has forms with phx-submit="remove_tag_bulk" and hidden inputs with the tag value
# After removal, the tag should not be in this section (though it may still exist in the global tags list)
refute html =~ ~r/phx-submit="remove_tag_bulk"[^>]*>.*?value="remove-me"/s
```

With:
```elixir
# Tag should not appear in the multi-select panel's removable tags section
removable_tags = extract_removable_tags(html)
refute "remove-me" in removable_tags
```

## Verification

### After Making Changes

1. **Run the test suite:**
   ```bash
   docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/main_test.exs
   ```

2. **Verify specific test:**
   ```bash
   # Test should still be skipped but with better documentation
   docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/main_test.exs:391

   # Bulk tag removal test should pass with clearer assertion
   docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/main_test.exs:763
   ```

3. **Expected results:**
   - Scroll test remains skipped with improved documentation
   - Bulk tag removal test passes with clearer, more maintainable assertion
   - All other tests continue to pass as before

## Files to Modify

- `app/test/photo_tagger_web/live/gallery_live/main_test.exs` - Update scroll test comment, add helper, update assertion

## Notes

- These are quality-of-life improvements to test maintainability
- No functional behavior changes to the application
- The scroll test remains skipped by design until Phoenix upgrade
- The improved assertion is more robust and follows existing helper patterns
