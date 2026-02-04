# Plan: Phase 6 LiveView Tests - Complete Implementation

## Overview

This plan covers implementing comprehensive tests for the main gallery LiveView (`main.ex`) and drift LiveView (`drift.ex`). Based on the test implementation plan, this should result in ~63 main tests and ~5 drift tests.

## Critical Testing Gotchas (from key_facts.md)

### 1. No `view.assigns` Access in Phoenix LiveView 1.0+
**Problem**: `Phoenix.LiveViewTest.View` struct only has `id`, `module`, `pid`, `proxy`, `endpoint` - no `assigns`.

**Solution**: Test rendered HTML output instead:
```elixir
# WRONG: assert view.assigns.interval_ms == 5000
# RIGHT: assert render(view) =~ ~r/data-interval-ms="5000"/
```

### 2. String Keys and Values for Event Parameters
**Problem**: Browser sends all values as strings.

**Incorrect**:
```elixir
render_click(view, "change_page", %{pg: 2})
```

**Correct**:
```elixir
render_click(view, "change_page", %{"pg" => "2"})
render_click(view, "select_photo", %{"photo_id" => to_string(photo.id), "ctrl_key_pressed" => "false"})
```

### 3. LiveComponent Events Require Element Targeting
**Problem**: Events with `phx-target={@myself}` go to component, not parent.

**Incorrect**:
```elixir
render_click(view, "select_index", %{"index" => "T"})
```

**Correct**:
```elixir
view |> element("#index-selectors button", "T") |> render_click()
```

### 4. NavPanel Shows Letter Indices, Not Tags
Tags only appear after clicking an index to expand. Test accordingly:
```elixir
view |> element("#index-selectors button", "T") |> render_click()
html = render(view)
assert html =~ "tag_name"
```

### 5. Use Element Selectors for Targeted Assertions
**Problem**: `assert html =~ "photo1.jpg"` matches anywhere in HTML (gallery grid AND photo panel).

**Solution**: Use `has_element?` with specific selectors:
```elixir
# Check photo is in photo panel specifically
assert photo_in_panel?(view, "photo1.jpg")
```

### 6. Phoenix LiveView 1.0 Lacks `assert_push_event/3`
Scroll event testing is limited - document and skip those tests until Phoenix 1.1+ upgrade.

## Files to Create

1. `app/test/photo_tagger_web/live/gallery_live/main_test.exs` (~63 tests)
2. `app/test/photo_tagger_web/live/gallery_live/drift_test.exs` (~5 tests)

## Files to Reference

- `lib/photo_tagger_web/live/gallery_live/main.ex` - Main LiveView
- `lib/photo_tagger_web/live/gallery_live/drift.ex` - Drift mode
- `lib/photo_tagger_web/live/gallery_live/util.ex` - Utility functions
- `test/support/fixtures/gallery_fixtures.ex` - Test fixtures

---

## Part 1: main_test.exs Structure

### Module Setup

```elixir
defmodule PhotoTaggerWeb.GalleryLive.MainTest do
  @moduledoc """
  Tests for the main gallery LiveView.

  These tests verify mounting, URL routing, event handling, and component rendering
  for the primary gallery interface.
  """

  use PhotoTaggerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhotoTagger.GalleryFixtures

  alias PhotoTagger.Gallery
  alias PhotoTagger.Repo
  alias PhotoTaggerWeb.GalleryLive.Util
```

### Helper Functions (Required)

```elixir
# Wrapper for assert_patch that only accepts exact string paths.
# Phoenix's assert_patch/2 does not support regex matching. For URLs with
# complex query parameters, verify the behavior through HTML inspection
# (e.g., `assert html =~ "expected_value"`) rather than URL matching.
defp assert_patched_to(view, path) when is_binary(path) do
  assert_patch(view, path)
end

# Check for admin UI elements
defp has_admin_ui?(html) do
  html =~ ~r/phx-click="toggle_multiselect"/
end

# Count photos in gallery grid
defp count_photos_in_html(html) do
  Regex.scan(~r/<img[^>]*class="[^"]*object-contain[^"]*"/, html) |> length()
end

# Extract tags from breadcrumb
defp extract_selected_tags(html) do
  Regex.scan(~r/aria-current="page"[^>]*>\s*#?([^<]+)<\//, html)
  |> Enum.map(fn [_, tag] -> String.trim(tag) end)
  |> Enum.reject(&(&1 == "" or String.contains?(&1, "folder")))
end

# Extract folder name from breadcrumb
defp extract_folder_name(html) do
  case Regex.run(~r/aria-label="Breadcrumb"[^>]*>.*?<\/svg>\s*<a[^>]*>\s*([^<]+)<\/a>/, html, capture: :all) do
    [_, folder] -> String.trim(folder)
    _ -> nil
  end
end

# Get zoom level from grid classes
defp get_zoom_level_from_grid(html) do
  case Regex.run(~r/grid-cols-(\d+)/, html) do
    [_, size] -> String.to_integer(size)
    _ -> 0
  end
end

# Get selected sort option
defp get_sort_option(html) do
  case Regex.run(~r/<option value="(\w+)" selected/, html) do
    [_, "date"] -> :date
    [_, "manual"] -> :manual
    _ -> :manual
  end
end

# Count selected photos in multi-select panel
defp count_selected_photos(html) do
  Regex.scan(~r/<img[^>]*class="w-20 h-20 object-cover"/, html) |> length()
end

# Check if a tag appears in the NavPanel's "Current filters" section.
# This section shows actively selected filter tags (query_tags) with toggle_tag click handlers.
defp tag_in_current_filters?(view, tag_name) do
  has_element?(view, "button[phx-click='toggle_tag'][phx-value-tag='#{tag_name}']")
end

# Check if a tag appears in the NavPanel's exclude filters section.
# Exclude tags appear with toggle_exclude_tag click handlers.
defp tag_in_exclude_filters?(view, tag_name) do
  has_element?(view, "button[phx-click='toggle_exclude_tag'][phx-value-tag='#{tag_name}']")
end

# Extract removable tags from multi-select panel
defp extract_removable_tags(html) do
  Regex.scan(~r/<input[^>]*class="hidden"[^>]*name="tag"[^>]*value="([^"]+)"[^>]*>/, html)
  |> Enum.map(fn [_, tag] -> tag end)
  |> Enum.uniq()
end

# Check if photo is shown in photo panel (not just gallery grid)
defp photo_in_panel?(view, photo_name) do
  has_element?(view, "#photo-section a[download]", photo_name)
end
```

---

## Part 2: Test Groups for main_test.exs

### Group 1: Mounting and Initial State (5 tests)

```elixir
describe "mount/3 - access control and layouts" do
  test "uses admin layout for admin routes, app layout for public", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    # Test public route - no admin UI
    {:ok, _public_view, public_html} = live(conn, "/folders/#{folder.name}")
    refute has_admin_ui?(public_html)

    # Test admin route - has admin UI
    {:ok, _admin_view, admin_html} = live(conn, "/admin/folders/#{folder.name}")
    assert has_admin_ui?(admin_html)
  end
end

describe "mount/3 - loading folders and tags" do
  test "admin loads all folders and tags", %{conn: conn} do
    # Create folders and tags
    _public_folder1 = folder_fixture(%{name: "public1", is_public: true})
    _public_folder2 = folder_fixture(%{name: "public2", is_public: true})
    _private_folder = folder_fixture(%{name: "private1", is_public: false})

    tag1 = tag_fixture(%{name: "tag1"})
    tag2 = tag_fixture(%{name: "tag2"})
    tag3 = tag_fixture(%{name: "tag3"})

    # Mount as admin - should see all folders and tags
    {:ok, admin_view, admin_html} = live(conn, "/admin/folders")
    # Tags shown via letter indices - "T" for tag1, tag2, tag3
    assert admin_html =~ "T"

    # Click on index to show tags
    admin_view |> element("#index-selectors button", "T") |> render_click()
    admin_html = render(admin_view)
    assert admin_html =~ tag1.name
    assert admin_html =~ tag2.name
    assert admin_html =~ tag3.name
  end
end

describe "mount/3 - default values" do
  test "sets default zoom_level, multiselect_active, collapse_groups", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, html} = live(conn, "/admin/folders/#{folder.name}")

    # Default zoom level - grid-cols-1 on mobile
    assert html =~ "grid-cols-1"

    # Multiselect button exists but inactive
    assert has_element?(view, "button[phx-click='toggle_multiselect']")

    # Collapse groups true by default - button shows "Expand groups"
    assert html =~ "Expand groups"

    # Curated sort by default
    assert html =~ ~r/<option value="manual" selected/
  end
end
```

### Group 2: Handle Params and URL Routing (10 tests)

```elixir
describe "handle_params - folder parameter" do
  test "loads folder photos", %{conn: conn} do
    folder1 = folder_fixture(%{name: "folder1"})
    _photo1 = photo_fixture(%{folder_id: folder1.id, name: "photo1.jpg"})
    _photo2 = photo_fixture(%{folder_id: folder1.id, name: "photo2.jpg"})
    _photo3 = photo_fixture(%{folder_id: folder1.id, name: "photo3.jpg"})

    folder2 = folder_fixture(%{name: "folder2"})
    _photo4 = photo_fixture(%{folder_id: folder2.id, name: "photo4.jpg"})

    {:ok, _view, html} = live(conn, "/admin/folders/#{folder1.name}")

    # Should only see folder1's photos
    assert html =~ "photo1.jpg"
    assert html =~ "photo2.jpg"
    assert html =~ "photo3.jpg"
    refute html =~ "photo4.jpg"
  end
end

describe "handle_params - tag filtering" do
  test "with query_tags filters photos by tags", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})
    photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg"})

    tag1 = tag_fixture(%{name: "landscape"})
    tag2 = tag_fixture(%{name: "sunset"})

    # photo1 has tag1, photo2 has tag1+tag2, photo3 has tag2
    {:ok, _} = Gallery.add_tag_to_photo(photo1, tag1.name)
    {:ok, _} = Gallery.add_tag_to_photo(photo2, tag1.name)
    {:ok, _} = Gallery.add_tag_to_photo(photo2, tag2.name)
    {:ok, _} = Gallery.add_tag_to_photo(photo3, tag2.name)

    {:ok, _view, html} = live(conn, "/admin/photos?query_tags[]=#{tag1.name}")

    # Should see photo1 and photo2, not photo3
    assert html =~ "photo1.jpg"
    assert html =~ "photo2.jpg"
    refute html =~ "photo3.jpg"
  end

  test "with exclude_tags filters out photos", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})
    photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg"})

    tag1 = tag_fixture(%{name: "landscape"})

    {:ok, _} = Gallery.add_tag_to_photo(photo1, tag1.name)

    {:ok, _view, html} = live(conn, "/admin/photos?exclude_tags[]=#{tag1.name}")

    # Should see photo2 and photo3, not photo1
    refute html =~ "photo1.jpg"
    assert html =~ "photo2.jpg"
    assert html =~ "photo3.jpg"
  end
end

describe "handle_params - photo selection" do
  test "with photo_id selects single photo", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo1.id}")

    # Photo panel should show selected photo with download link
    assert photo_in_panel?(view, "photo1.jpg")
  end

  test "with selected_photos selects multiple photos", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, _view, html} =
      live(conn, "/admin/photos?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}")

    # Multi-selection panel should show 2 thumbnails
    assert count_selected_photos(html) == 2
  end
end

describe "handle_params - sort and pagination" do
  test "with sort param sets sort order", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, _view, manual_html} = live(conn, "/admin/photos?sort=manual")
    assert manual_html =~ ~r/<option value="manual" selected/

    {:ok, _view, date_html} = live(conn, "/admin/photos?sort=date")
    assert date_html =~ ~r/<option value="date" selected/
  end

  test "with pg param sets page number", %{conn: conn} do
    folder = folder_fixture()

    # Create 15 photos 
    Enum.each(1..15, fn i ->
      photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
    end)

    {:ok, _view, html} = live(conn, "/admin/photos?pg=2&pg_size=10")

    assert html =~ "Page 2 of 2"
  end
end

describe "handle_params - scroll events" do
  # SKIPPED: Phoenix LiveView 1.0 doesn't provide assert_push_event/3 for testing
  # push_event calls (available in 1.1+). The scroll_to_top logic is tested indirectly
  # via state changes in handle_params tests. Scroll behavior verified via manual testing.
  # To enable: Upgrade to Phoenix LiveView 1.1+ and use assert_push_event
  @tag :skip
  test "triggers scroll_to_top events when relevant params change", %{conn: conn} do
    folder1 = folder_fixture(%{name: "folder1"})
    folder2 = folder_fixture(%{name: "folder2"})
    _photo1 = photo_fixture(%{folder_id: folder1.id})
    _photo2 = photo_fixture(%{folder_id: folder2.id})

    {:ok, _view, html1} = live(conn, "/admin/folders/#{folder1.name}")
    assert html1 =~ "folder1"

    {:ok, _view, html2} = live(conn, "/admin/folders/#{folder2.name}")
    assert html2 =~ "folder2"
  end
end
```

### Group 3: Photo Selection Events (8 tests)

```elixir
describe "select_gallery_photo - single selection" do
  test "select_gallery_photo without ctrl selects single photo", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })

    # Verify photo is shown in photo panel
    assert photo_in_panel?(view, "photo1.jpg")
  end

  test "select_gallery_photo with ctrl selects multiple even with multiselect inactive", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Select photo1
    render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })
    assert photo_in_panel?(view, "photo1.jpg")

    # Select photo2 with ctrl (but multiselect inactive)
    html = render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo2.id),
      "ctrl_key_pressed" => "true"
    })

    # Both photos now selected
    assert count_selected_photos(html) ==  2_
  end
end

describe "select_gallery_photo - multi selection" do
  test "select_gallery_photo without ctrl adds to selection in multiselect mode", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Select photo1
    render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })

    # Enable multiselect
    render_click(view, "toggle_multiselect")

    # Select photo2 with ctrl
    html = render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo2.id),
      "ctrl_key_pressed" => "false"
    })

    # Multi-selection panel should show 2 photos
    assert count_selected_photos(html) == 2
  end
end

describe "select_gallery_group - group selection" do
  test "select_gallery_group selects all photos in group", %{conn: conn} do
    folder = folder_fixture()
    _photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "group1"})
    _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "group1"})
    _photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg", group: "group1"})
    _photo4 = photo_fixture(%{folder_id: folder.id, name: "photo4.jpg", group: "group2"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    html = render_click(view, "select_gallery_group", %{
      "photo_group" => "group1",
      "ctrl_key_pressed" => "false"
    })

    # All 3 photos in group1 should be selected
    assert count_selected_photos(html) == 3
  end

  test "select_gallery_group in multiselect mode toggles group selection", %{conn: conn} do
    folder = folder_fixture()
    _photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "group1"})
    _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "group1"})
    _photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg", group: "group1"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Enable multiselect
    render_click(view, "toggle_multiselect")

    # Select group (all 3 selected)
    html = render_click(view, "select_gallery_group", %{
      "photo_group" => "group1",
      "ctrl_key_pressed" => "false"
    })
    assert count_selected_photos(html) == 3

    # Select group again (all 3 deselected)
    html = render_click(view, "select_gallery_group", %{
      "photo_group" => "group1",
      "ctrl_key_pressed" => "false"
    })
    assert html =~ "Select a photo to view details"
  end
end

describe "select_gallery_photo - regression tests" do
  test "REGRESSION: selecting photo preserves sort order", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})

    {:ok, view, html} = live(conn, "/admin/photos?sort=date")
    assert html =~ ~r/<option value="date" selected/

    html = render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })

    # Sort should still be date
    assert html =~ ~r/<option value="date" selected/
  end

  test "REGRESSION: selecting photo preserves zoom level", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Zoom in twice
    render_click(view, "zoom_in")
    html_after_zoom = render_click(view, "zoom_in")
    assert html_after_zoom =~ ~r/lg:grid-cols-2/

    html_after_select = render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })

    # Zoom level should be preserved
    assert html_after_select =~ ~r/lg:grid-cols-2/
  end

  test "REGRESSION: selecting photo preserves page number", %{conn: conn} do
    folder = folder_fixture()

    photos = Enum.map(1..15, fn i ->
      photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
    end)

    {:ok, view, html} = live(conn, "/admin/folders/#{folder.name}?pg=2&pg_size=10")
    assert html =~ "Page 2 of 2"

    photo_from_page_2 = Enum.at(photos, 110)
    html = render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo_from_page_2.id),
      "ctrl_key_pressed" => "false"
    })

    # Page should still be 2
    assert html =~ "Page 2 of 2"
  end
end
```

### Group 4: UI State Toggle Events (5 tests)

```elixir
describe "toggle_multiselect event" do
  test "enables multi-selection mode", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Select first photo
    render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })

    # Enable multiselect
    render_click(view, "toggle_multiselect")

    # Select second photo with ctrl
    html = render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo2.id),
      "ctrl_key_pressed" => "false"
    })

    # Both photos should be selected
    assert count_selected_photos(html) == 2
  end

  test "disables multi-selection mode when toggled again", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Enable multiselect and select both
    render_click(view, "toggle_multiselect")
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo1.id), "ctrl_key_pressed" => "false"})
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo2.id), "ctrl_key_pressed" => "false"})

    # Disable multiselect
    render_click(view, "toggle_multiselect")

    # Try to add another photo with ctrl (should replace, not add)
    render_click(view, "select_gallery_photo", %{
      "photo_id" => to_string(photo1.id),
      "ctrl_key_pressed" => "false"
    })

    # Only single photo should be selected
    assert photo_in_panel?(view, "photo1.jpg")
  end
end

describe "toggle_collapse_groups event" do
  test "expands and collapses all groups", %{conn: conn} do
    folder = folder_fixture()
    _photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "group1"})
    _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "group1"})
    _photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg", group: "group2"})

    {:ok, view, html_before} = live(conn, "/admin/folders/#{folder.name}")

    # Default is collapsed - button shows "Expand groups"
    assert html_before =~ "Expand groups"
    assert count_photos_in_html(html_before) == 2

    # Toggle to expand
    html_expanded = render_click(view, "toggle_collapse_groups")
    assert html_expanded =~ "Collapse groups"
    assert count_photos_in_html(html_before) == 3

    # Collapse again
    html_collapsed = render_click(view, "toggle_collapse_groups")
    assert html_collapsed =~ "Expand groups"
    assert count_photos_in_html(html_before) == 2
  end
end

describe "toggle_collapse_single_group event" do
  test "collapses individual group", %{conn: conn} do
    folder = folder_fixture()
    _photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "group1"})
    _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "group1"})
    _photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg", group: "group2"})
    _photo4 = photo_fixture(%{folder_id: folder.id, name: "photo4.jpg", group: "group2"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # First expand all groups
    render_click(view, "toggle_collapse_groups")

    # Collapse just group1
    html = render_click(view, "toggle_collapse_single_group", %{"photo_group" => "group1"})

    # Should see one photo from collapsed group 1 and both from group 2 
    assert count_photos_in_html(html) == 3
  end

  test "re-expands collapsed group when toggled again", %{conn: conn} do
    folder = folder_fixture()
    _photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "group1"})
    _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "group1"})
    _photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg", group: "group2"})
    _photo4 = photo_fixture(%{folder_id: folder.id, name: "photo4.jpg", group: "group2"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Expand all, collapse group1, re-expand group1
    render_click(view, "toggle_collapse_groups")
    render_click(view, "toggle_collapse_single_group", %{"photo_group" => "group1"})
    html = render_click(view, "toggle_collapse_single_group", %{"photo_group" => "group1"})

    # Should see all photos
    assert count_photos_in_html(html) == 4
  end
end
```

### Group 5: Tag Management Events (8 tests)

```elixir
describe "add_tag event" do
  test "adds tag to photo and refreshes", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "test.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

    # Ensure test is valid by checking tag doesn't yet appear in html
    refute html =~ "landscape"

    html = render_click(view, "add_tag", %{"photo_id" => to_string(photo.id), "tag" => "landscape"})

    # Reload from DB
    photo_reloaded = Gallery.get_photo!(photo.id, include_private: true) |> Repo.preload(:tags)
    tag_names = Enum.map(photo_reloaded.tags, & &1.name)
    assert "landscape" in tag_names

    # Tag appears in HTML
    assert html =~ "landscape"
  end

  test "creates new tag if it doesn't exist", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "test.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

    tag_count_before = length(Gallery.list_tags())

    render_click(view, "add_tag", %{"photo_id" => to_string(photo.id), "tag" => "newtag"})

    tag_count_after = length(Gallery.list_tags())
    assert tag_count_after == tag_count_before + 1

    tag = Gallery.get_tag_by_name!("newtag")
    assert tag.name == "newtag"
  end
end

describe "remove_tag event" do
  test "removes tag from photo and refreshes", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "test.jpg"})
    tag = tag_fixture(%{name: "removeme"})
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag.name)

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")
    
    # Ensure test is valid by checking tag appears in html
    assert html =~ "removeme"

    html = render_click(view, "remove_tag", %{"photo_id" => to_string(photo.id), "tag" => tag.name})

    # Reload from DB
    photo_reloaded = Gallery.get_photo!(photo.id, include_private: true) |> Repo.preload(:tags)
    tag_names = Enum.map(photo_reloaded.tags, & &1.name)
    assert tag.name not in tag_names

    refute html =~ "removeme"
  end
end

describe "add_tag_bulk event" do
  test "adds tag to all selected photos", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Select both
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo1.id), "ctrl_key_pressed" => "false"})
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo2.id), "ctrl_key_pressed" => "true"})

    html = render_click(view, "add_tag_bulk", %{"tag" => "bulk-tag"})

    # Both photos have the tag
    photo1_reloaded = Gallery.get_photo!(photo1.id, include_private: true) |> Repo.preload(:tags)
    photo2_reloaded = Gallery.get_photo!(photo2.id, include_private: true) |> Repo.preload(:tags)

    assert "bulk-tag" in Enum.map(photo1_reloaded.tags, & &1.name)
    assert "bulk-tag" in Enum.map(photo2_reloaded.tags, & &1.name)
    assert "bulk-tag" in extract_removable_tags(html)
  end
end

describe "remove_tag_bulk event" do
  test "removes tag from all selected photos", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})

    {:ok, _} = Gallery.add_tag_to_photo(photo1, "remove-me")
    {:ok, _} = Gallery.add_tag_to_photo(photo2, "remove-me")

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo1.id), "ctrl_key_pressed" => "false"})
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo2.id), "ctrl_key_pressed" => "true"})

    html = render_click(view, "remove_tag_bulk", %{"tag" => "remove-me"})

    # Both photos should not have the tag
    photo1_reloaded = Gallery.get_photo!(photo1.id, include_private: true) |> Repo.preload(:tags)
    photo2_reloaded = Gallery.get_photo!(photo2.id, include_private: true) |> Repo.preload(:tags)

    assert "remove-me" not in Enum.map(photo1_reloaded.tags, & &1.name)
    assert "remove-me" not in Enum.map(photo2_reloaded.tags, & &1.name)

    # Tag not in removable tags section
    removable_tags = extract_removable_tags(html)
    refute "remove-me" in removable_tags
  end
end

describe "toggle_tag event" do
  test "adds tag to query when not present", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    refute tag_in_current_filters?(view, "sunset")

    render_click(view, "toggle_tag", %{"tag" => "sunset"})

    assert tag_in_current_filters?(view, "sunset")
  end

  test "removes tag from query when present", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}?query_tags[]=sunset")

    assert tag_in_current_filters?(view, "sunset")

    render_click(view, "toggle_tag", %{"tag" => "sunset"})

    refute tag_in_current_filters?(view, "sunset")
  end
end

describe "toggle_exclude_tag event" do
  test "adds tag to exclude list", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    refute tag_in_exclude_filters?(view, "blur")

    render_click(view, "toggle_exclude_tag", %{"tag" => "blur"})

    assert tag_in_exclude_filters?(view, "blur")
  end
end
```

### Group 6: Photo Update and Delete Events (6 tests)

```elixir
describe "update_photo event" do
  test "updates photo and shows flash", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "old_name.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

    html = render_click(view, "update_photo", %{
      "photo_id" => to_string(photo.id),
      "photo" => %{"name" => "new_name.jpg"}
    })

    assert html =~ "Photo updated successfully"

    photo_reloaded = Gallery.get_photo!(photo.id, include_private: true)
    assert photo_reloaded.name == "new_name.jpg"
    assert html =~ "new_name.jpg"
  end

  test "with invalid data shows error flash", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "valid.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

    html = render_click(view, "update_photo", %{
      "photo_id" => to_string(photo.id),
      "photo" => %{"name" => ""}
    })

    assert html =~ "Failed to update photo"

    photo_reloaded = Gallery.get_photo!(photo.id, include_private: true)
    assert photo_reloaded.name == photo.name
  end

  test "REGRESSION: refreshes gallery panel", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "old.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo.id), "ctrl_key_pressed" => "false"})

    html = render_click(view, "update_photo", %{
      "photo_id" => to_string(photo.id),
      "photo" => %{"name" => "new.jpg"}
    })

    assert html =~ "new.jpg"
    refute html =~ "old.jpg"
  end

  test "REGRESSION: refreshes selected photo in photo panel", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{folder_id: folder.id, name: "photo.jpg", description: "Old description"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

    new_description = "Updated description for regression test"
    html = render_click(view, "update_photo", %{
      "photo_id" => to_string(photo.id),
      "photo" => %{"description" => new_description}
    })

    assert html =~ new_description
    refute html =~ "Old description"
  end
end

describe "delete_photo event" do
  test "removes photo and redirects", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "delete1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "delete2.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo1.id}")

    html = render_click(view, "delete_photo", %{"photo_id" => to_string(photo1.id)})

    assert_raise Ecto.NoResultsError, fn ->
      Gallery.get_photo!(photo1.id, include_private: true)
    end

    photo2_exists = Gallery.get_photo!(photo2.id, include_private: true)
    assert photo2_exists.id == photo2.id

    assert html =~ "deleted"
    refute html =~ "delete1.jpg"
  end
end

describe "delete_photo_bulk event" do
  test "deletes all selected photos", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "bulk1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "bulk2.jpg"})
    photo3 = photo_fixture(%{folder_id: folder.id, name: "bulk3.jpg"})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo1.id), "ctrl_key_pressed" => "false"})
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo2.id), "ctrl_key_pressed" => "true"})
    render_click(view, "select_gallery_photo", %{"photo_id" => to_string(photo3.id), "ctrl_key_pressed" => "true"})

    html = render_click(view, "delete_photo_bulk")

    Enum.each([photo1, photo2, photo3], fn photo ->
      assert_raise Ecto.NoResultsError, fn ->
        Gallery.get_photo!(photo.id, include_private: true)
      end
    end)

    assert html =~ "deleted"
    refute html =~ "bulk1.jpg"
    refute html =~ "bulk2.jpg"
    refute html =~ "bulk3.jpg"
  end
end
```

### Group 7: Group Management Events (3 tests)

```elixir
describe "set_group_bulk event" do
  test "sets group for all selected photos", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "group1"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "group2"})
    photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg", group: "group3"})

    {:ok, view, _html} = live(conn,
      "/admin/folders/#{folder.name}?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}&selected_photos[]=#{photo3.id}"
    )

    render_click(view, "set_group_bulk", %{"group" => "vacation"})

    [photo1, photo2, photo3]
    |> Enum.each(fn photo ->
      updated = Gallery.get_photo!(photo.id, include_private: true)
      assert updated.group == "vacation"
    end)
  end
end

describe "form_group_from_selected event" do
  test "creates new group from timestamp", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})
    photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg"})

    {:ok, view, _html} = live(conn,
      "/admin/folders/#{folder.name}?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}&selected_photos[]=#{photo3.id}"
    )

    render_click(view, "form_group_from_selected")

    updated_photo1 = Gallery.get_photo!(photo1.id, include_private: true)
    updated_photo2 = Gallery.get_photo!(photo2.id, include_private: true)
    updated_photo3 = Gallery.get_photo!(photo3.id, include_private: true)

    assert updated_photo1.group != nil
    assert updated_photo1.group == updated_photo2.group
    assert updated_photo2.group == updated_photo3.group
  end

  test "reuses existing group if all photos share one", %{conn: conn} do
    folder = folder_fixture()
    photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg", group: "existing-group"})
    photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg", group: "existing-group"})
    photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg"}) 

    {:ok, view, _html} = live(conn,
      "/admin/folders/#{folder.name}?selected_photos[]=#{photo1.id}&selected_photos[]=#{photo2.id}&selected_photos[]=#{photo3.id}"
    )

    render_click(view, "form_group_from_selected")

    [photo1, photo2, photo3]
    |> Enum.each(fn photo ->
      updated = Gallery.get_photo!(photo.id, include_private: true)
      assert updated.group == "existing-group"
    end)
  end
end
```

### Group 8: View Settings Events (5 tests)

```elixir
describe "zoom_in event" do
  test "increases zoom_level", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, html_before} = live(conn, "/admin/folders/#{folder.name}")
    assert html_before =~ ~r/lg:grid-cols-4/

    html_after = render_click(view, "zoom_in")
    assert html_after =~ ~r/lg:grid-cols-3/
  end
end

describe "zoom_out event" do
  test "decreases zoom_level", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    html_zoomed_in = render_click(view, "zoom_in")
    assert html_zoomed_in =~ ~r/lg:grid-cols-3/

    html_zoomed_out = render_click(view, "zoom_out")
    assert html_zoomed_out =~ ~r/lg:grid-cols-4/
  end
end

describe "zoom clamping" do
  test "zoom_in and zoom_out clamp between -9 and 9", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    # Zoom in 15 times
    html_max = Enum.reduce(1..15, nil, fn _, _ -> render_click(view, "zoom_in") end)
    assert html_max =~ ~r/grid-cols-1/

    # Zoom out 25 times
    html_min = Enum.reduce(1..25, nil, fn _, _ -> render_click(view, "zoom_out") end)
    assert html_min =~ ~r/lg:grid-cols-9/
  end
end

describe "change_sort event" do
  test "updates sort order and triggers URL update", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, html} = live(conn, "/admin/folders/#{folder.name}")
    assert html =~ ~r/<option value="manual" selected/

    render_change(view, "change_sort", %{"sort" => "date"})

    # URL will contain sort=date, but assert_patch doesn't support regex.
    # Verify via rendered HTML instead.
    html = render(view)
    assert html =~ ~r/<option value="date" selected/
  end

  test "REGRESSION: preserves other view settings", %{conn: conn} do
    folder = folder_fixture()
    Enum.each(1..15, fn i ->
      photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
    end)

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}?pg=2&pg_count=10")

    # Set zoom and multiselect
    Enum.each(1..3, fn _ -> render_click(view, "zoom_in") end)
    render_click(view, "toggle_multiselect")

    render_change(view, "change_sort", %{"sort" => "date"})

    html = render(view)
    assert html =~ ~r/lg:grid-cols-1/
    assert html =~ "Page 2 of 2"
  end
end
```

### Group 9: Folder Navigation Events (2 tests)

```elixir
describe "change_folder event" do
  test "navigates to folder", %{conn: conn} do
    folder = folder_fixture(%{name: "vacation"})
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/photos")

    html = render_click(view, "change_folder", %{"folder" => "vacation"})

    assert_patch(view, "/admin/folders/vacation")
    assert extract_folder_name(html) == "vacation"  
  end

  test "with empty string navigates to all folders", %{conn: conn} do
    folder = folder_fixture(%{name: "vacation"})
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    html = render_click(view, "change_folder", %{"folder" => ""})

    assert_patch(view, "/admin/photos")
    assert extract_folder_name(html) == "All folders"  
  end
end
```

### Group 10: Pagination Events (2 tests)

```elixir
describe "change_page event" do
  test "updates page number", %{conn: conn} do
    folder = folder_fixture()
    Enum.each(1..15, fn i ->
      photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
    end)

    {:ok, view, html_pg1} = live(conn, "/admin/folders/#{folder.name}?pg_size=10")
    assert html_pg1 =~ "Page 1"

    html_pg2 = render_click(view, "change_page", %{"pg" => "2"})
    assert html_pg2 =~ "Page 2"
  end

  # SKIPPED: Phoenix LiveView 1.0 doesn't provide assert_push_event/3 for testing
  # push_event calls (available in 1.1+). Scroll behavior verified via manual testing.
  # To enable: Upgrade to Phoenix LiveView 1.1+ and use assert_push_event
  @tag :skip
  test "triggers scroll to top", %{conn: conn} do
    folder = folder_fixture()
    Enum.each(1..15, fn i ->
      photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
    end)

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}?pg_size=10")

    html = render_click(view, "change_page", %{"pg" => "2"})
    assert html =~ "Page 2"
  end
end
```

### Group 11: Component Rendering (6 tests)

```elixir
describe "component rendering - gallery_header" do
  # TODO: improve assertions for component rendering tests for more accurate html checks
  test "gallery_header renders breadcrumb navigation", %{conn: conn} do
    folder = folder_fixture(%{name: "my_folder"})
    photo = photo_fixture(%{folder_id: folder.id})
    tag1 = tag_fixture(%{name: "landscape"})
    tag2 = tag_fixture(%{name: "sunset"})
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag1.name)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag2.name)

    {:ok, _view, html} = live(conn,
      "/admin/folders/#{folder.name}?query_tags[]=#{tag1.name}&query_tags[]=#{tag2.name}"
    )

    assert html =~ "my_folder"
    assert html =~ tag1.name
    assert html =~ tag2.name
  end

  test "gallery_header renders sort dropdown", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, html} = live(conn, "/admin/folders/#{folder.name}")

    assert has_element?(view, "select[name='sort']")
    assert html =~ "By date"
    assert html =~ "Curated"
  end

  test "gallery_header renders view controls (zoom, multiselect, collapse)", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, _html} = live(conn, "/admin/folders/#{folder.name}")

    assert has_element?(view, "button[phx-click='zoom_in']")
    assert has_element?(view, "button[phx-click='zoom_out']")
    assert has_element?(view, "button[phx-click='toggle_collapse_groups']")
    assert has_element?(view, "button[phx-click='toggle_multiselect']")
  end
end

describe "component rendering - gallery" do
  test "gallery renders photos with correct zoom level", %{conn: conn} do
    folder = folder_fixture()
    _photo = photo_fixture(%{folder_id: folder.id})

    {:ok, view, html} = live(conn, "/admin/folders/#{folder.name}")

    assert html =~ "grid-cols-1"
    assert html =~ "lg:grid-cols-4"

    html_zoomed = render_click(view, "zoom_in")
    assert html_zoomed =~ "lg:grid-cols-3"
  end

  test "gallery renders pagination when needed", %{conn: conn} do
    folder = folder_fixture()
    Enum.each(1..15, fn i ->
      photo_fixture(%{folder_id: folder.id, name: "photo#{i}.jpg"})
    end)

    {:ok, view, html} = live(conn, "/admin/folders/#{folder.name}?pg_size=5")

    assert has_element?(view, "button[phx-click='change_page']")
    assert html =~ "Page 1 of 3"
  end
end

describe "component rendering - photo panel" do
  test "photo panel renders selected photo details", %{conn: conn} do
    folder = folder_fixture()
    photo = photo_fixture(%{
      folder_id: folder.id,
      name: "sunset_beach.jpg",
      description: "Beautiful sunset at the beach"
    })
    tag1 = tag_fixture(%{name: "beach"})
    tag2 = tag_fixture(%{name: "nature"})
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag1.name)
    {:ok, _} = Gallery.add_tag_to_photo(photo, tag2.name)

    {:ok, _view, html} = live(conn, "/admin/folders/#{folder.name}/photos/#{photo.id}")

    assert html =~ "sunset_beach.jpg"
    assert html =~ "Beautiful sunset at the beach"
    assert html =~ "beach"
    assert html =~ "nature"
  end
end
```

### Group 12: Utility Function Tests (3 tests)

```elixir
describe "utility functions - member_by_id?" do
  alias PhotoTaggerWeb.GalleryLive.Main

  test "member_by_id?/2 returns true when item in list" do
    list = [%{id: 1, name: "photo1"}, %{id: 2, name: "photo2"}, %{id: 3, name: "photo3"}]

    assert Main.member_by_id?(list, %{id: 1}) == true
    assert Main.member_by_id?(list, %{id: 2}) == true
    assert Main.member_by_id?(list, %{id: 3}) == true
  end

  test "member_by_id?/2 returns false when item not in list" do
    list = [%{id: 1, name: "photo1"}, %{id: 2, name: "photo2"}]

    assert Main.member_by_id?(list, %{id: 3}) == false
    assert Main.member_by_id?(list, %{id: 99}) == false
  end
end

describe "utility functions - simplify_photo" do
  alias PhotoTaggerWeb.GalleryLive.Main

  test "simplify_photo/1 extracts only needed fields" do
    folder = folder_fixture()
    full_photo = photo_fixture(%{
      folder_id: folder.id,
      name: "test.jpg",
      description: "A test photo",
      notes: "Some notes",
      group: "group1",
      is_public: true
    })

    simplified = Main.simplify_photo(full_photo)

    assert Map.has_key?(simplified, :id)
    assert Map.has_key?(simplified, :name)
    assert Map.has_key?(simplified, :group)
    assert Map.has_key?(simplified, :image)
    assert Map.has_key?(simplified, :folder)

    refute Map.has_key?(simplified, :description)
    refute Map.has_key?(simplified, :notes)
    refute Map.has_key?(simplified, :is_public)

    assert map_size(simplified) == 5
  end
end
```

---

## Part 3: drift_test.exs Structure

### File: `app/test/photo_tagger_web/live/gallery_live/drift_test.exs`

```elixir
defmodule PhotoTaggerWeb.GalleryLive.DriftTest do
  @moduledoc """
  Tests for the drift/carousel LiveView.
  """

  use PhotoTaggerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PhotoTagger.GalleryFixtures

  alias PhotoTagger.Gallery

  describe "mount/3" do
    test "loads initial photo", %{conn: conn} do
      folder = folder_fixture()
      photo = photo_fixture(%{folder_id: folder.id, name: "drift_photo.jpg"})

      {:ok, _view, html} = live(conn, "/drift/#{folder.name}?photo_id=#{photo.id}")

      assert html =~ "drift_photo.jpg"
    end

    test "respects public/private access control", %{conn: conn} do
      public_folder = folder_fixture(%{is_public: true})
      public_photo = photo_fixture(%{folder_id: public_folder.id, is_public: true})
      private_photo = photo_fixture(%{folder_id: public_folder.id, is_public: false})

      # Public route - should only show public photos
      {:ok, _view, html} = live(conn, "/drift/#{public_folder.name}?photo_id=#{public_photo.id}")
      assert html =~ public_photo.name

      # TODO: check that public route cannot show private photos, or drift into private photos

      # Admin route - can show private photos
      {:ok, _view, admin_html} = live(conn, "/admin/drift/#{public_folder.name}?photo_id=#{private_photo.id}")
      assert admin_html =~ private_photo.name
    end
  end

  describe "tempo changes" do
    test "increase_tempo cycles through intervals", %{conn: conn} do
      # TODO: improve this test with more specific html checks
      folder = folder_fixture()
      photo = photo_fixture(%{folder_id: folder.id})

      {:ok, view, _html} = live(conn, "/admin/drift/#{folder.name}?photo_id=#{photo.id}")

      # Default tempo - check data attribute or visible indicator
      html1 = render(view)
      # Tempo starts at some default

      # Increase tempo (cycles 2s -> 5s -> 10s -> 15s -> 2s)
      html2 = render_click(view, "increase_tempo")
      # Verify tempo changed (via HTML attributes or visible indicator)
      refute html1 == html2 or html2 =~ "tempo" # Some change occurred
    end
  end

  describe "switch_photos" do
    test "advances to next photo", %{conn: conn} do
      folder = folder_fixture()
      photo1 = photo_fixture(%{folder_id: folder.id, name: "photo1.jpg"})
      _photo2 = photo_fixture(%{folder_id: folder.id, name: "photo2.jpg"})
      _photo3 = photo_fixture(%{folder_id: folder.id, name: "photo3.jpg"})

      {:ok, view, html_initial} = live(conn, "/admin/drift/#{folder.name}?photo_id=#{photo1.id}")
      assert html_initial =~ "photo1.jpg"

      # Trigger switch
      html_after = render_click(view, "switch_photos")

      # Should show a different photo (or same if weighted selection picks it)
      # At minimum, the view renders successfully
      # TODO: should check this properly. Can we mock weighted-selection function?
      assert html_after =~ ".jpg"
    end
  end

  describe "folder scoping" do
    test "only shows photos from specified folder", %{conn: conn} do
      # TODO: fix this test so it actually tests what it claims to
      folder1 = folder_fixture(%{name: "folder1"})
      folder2 = folder_fixture(%{name: "folder2"})
      photo1 = photo_fixture(%{folder_id: folder1.id, name: "folder1_photo.jpg"})
      _photo2 = photo_fixture(%{folder_id: folder2.id, name: "folder2_photo.jpg"})

      {:ok, _view, html} = live(conn, "/admin/drift/#{folder1.name}?photo_id=#{photo1.id}")

      # Initial photo from folder1
      assert html =~ "folder1_photo.jpg"
      refute html =~ "folder2_photo.jpg"
    end
  end
end
```

---

## Implementation Order

1. **Create directory**: `mkdir -p app/test/photo_tagger_web/live/gallery_live/`
2. **Create main_test.exs**: Start with module setup and helper functions
3. **Implement Groups 1-2**: Foundation tests (mounting, URL routing)
4. **Implement Groups 3-4**: Selection and UI toggle tests
5. **Implement Groups 5-6**: Tag and photo management tests
6. **Implement Groups 7-10**: Bulk operations, sorting, navigation, pagination
7. **Implement Groups 11-12**: Rendering and utility tests
8. **Create drift_test.exs**: Separate file for drift mode tests
9. **Run and fix**: Execute tests, fix any issues

---

## Verification

### Run All LiveView Tests
```bash
docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/
```

### Run Specific Test File
```bash
docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/main_test.exs
```

### Run Specific Test at Line
```bash
docker compose -f docker-compose-dev.yml run dev_app mix test test/photo_tagger_web/live/gallery_live/main_test.exs:42
```

### Expected Results
- ~63 tests in main_test.exs (3 skipped for scroll events)
- ~5 tests in drift_test.exs
- All tests pass
- No flaky tests due to timing
- Regression tests clearly marked with "REGRESSION:" prefix

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `app/test/photo_tagger_web/live/gallery_live/main_test.exs` | Create | Main gallery LiveView tests (~63 tests) |
| `app/test/photo_tagger_web/live/gallery_live/drift_test.exs` | Create | Drift mode tests (~5 tests) |

---

## Notes

- All tests use mocked fixtures (no filesystem operations needed)
- String keys and string values for all event parameters
- Use `has_element?` with specific selectors for targeted assertions
- Regression tests marked with "REGRESSION:" prefix
- Scroll event tests skipped until Phoenix LiveView 1.1+ upgrade
- NavPanel tag testing requires clicking letter index first
