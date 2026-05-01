# Plan: Drag-and-Drop Photo Reordering (Issue #111)

## Context

Admins currently reorder photos by manually editing `manual_order` values. Issue #111 requests drag-and-drop reordering in the admin gallery grid for a more intuitive workflow. The backend already handles `manual_order` shifting via `reorder_photos_for_insert/3` and `do_update_photo/2` — no new backend logic is needed. SortableJS is installed (`app/assets/node_modules/sortablejs/`) but not yet integrated.

## Implementation

### 1. Create SortableJS LiveView Hook

**New file:** `app/assets/js/sortableGrid.js`

- Import SortableJS, export a hook object with `mounted()`, `updated()`, `destroyed()` lifecycle callbacks
- `mounted()`: Initialize `Sortable.create(this.el, ...)` with:
  - `animation: 150` for smooth transitions
  - `ghostClass`, `chosenClass`, `dragClass` for visual feedback
  - `draggable: "[data-gallery-photo-id]"` to target photo `<li>` elements
  - `disabled` controlled by `this.el.dataset.sortableEnabled === "true"`
  - `filter: "[data-group-collapsed]"` to prevent dragging collapsed group items
- `onEnd` callback: if position changed, extract `dragged_photo_id` and `target_photo_id` from `data-gallery-photo-id` attributes, then `this.pushEvent("reorder_photo", { dragged_photo_id, target_photo_id })`
- **DOM revert strategy**: Let SortableJS move the DOM, then let LiveView's morphdom reconcile on re-render. The `<ul>` and each `<li>` have stable IDs, so diffing should handle it. If flickering occurs, add explicit DOM revert in `onEnd` before pushing the event.
- `updated()`: Re-check `data-sortable-enabled` and toggle `this.sortable.option("disabled", !enabled)` — handles reactive enable/disable when sort mode or multiselect changes
- `destroyed()`: Call `this.sortable.destroy()`

### 2. Register Hook in app.js

**File:** `app/assets/js/app.js`

- Add `import SortableGrid from "./sortableGrid.js"`
- Add `SortableGrid` to the `hooks` object (alongside `CountdownTimer` and `ConfirmSubmit`)

### 3. Attach Hook to Gallery Grid

**File:** `app/lib/photo_tagger_web/live/gallery_live/main.ex`

- Add attrs to `gallery/1` component (~line 703): `attr(:sort, :atom, default: :manual)` and `attr(:multiselect_active, :boolean, default: false)`
- Pass `sort={@sort}` and `multiselect_active={@multiselect_active}` from the `<.gallery>` call (~line 58)
- Modify `<ul id="gallery-grid">` (~line 762) to add:
  ```
  phx-hook="SortableGrid"
  data-sortable-enabled={to_string(@is_admin and @sort == :manual and not @multiselect_active)}
  ```

### 4. Add `data-group-collapsed` to Collapsed Group Items

**File:** `app/lib/photo_tagger_web/live/gallery_live/gallery_photo.ex`

- Add `data-group-collapsed={if @is_group_collapsed, do: "true"}` to the `<li>` element (~line 21)
- This lets SortableJS's `filter` option skip collapsed group items

### 5. Add Server-Side Event Handler

**File:** `app/lib/photo_tagger_web/live/gallery_live/main.ex`

Add `handle_event("reorder_photo", params, socket)` near the existing photo update handlers:

- Guard: return `{:noreply, socket}` if not admin or sort != `:manual`
- Guard: return `{:noreply, socket}` if `dragged_photo.folder_id != target_photo.folder_id` (cross-folder safety)
- Fetch both photos via `Gallery.get_photo!/2`
- Call `Gallery.update_photo(dragged_photo, %{"manual_order" => target_photo.manual_order})`
  - This triggers `do_update_photo/2` → `reorder_photos_for_insert/3` which shifts other photos in the folder
  - Returns `{:ok, %{photo: photo, ...}}` on success (Ecto.Multi transaction result)
- On success: call `refresh_filtered_photos(socket)` to reload the grid with new ordering
- On error: `put_flash(socket, :error, "Failed to reorder photo.")`

### 6. Add Drag-and-Drop CSS

**File:** `app/assets/css/app.css`

Add styles for SortableJS classes:
- `.sortable-ghost` — reduced opacity + light background on the placeholder
- `.sortable-chosen` — outline on the picked-up element
- `.sortable-drag` — slight shadow on the dragged element

## Files Modified

| File | Change |
|------|--------|
| `app/assets/js/sortableGrid.js` | **New** — SortableJS LiveView hook |
| `app/assets/js/app.js` | Import + register `SortableGrid` hook |
| `app/lib/photo_tagger_web/live/gallery_live/main.ex` | Hook attrs on `<ul>`, new `handle_event`, pass `sort`/`multiselect_active` to `gallery/1` |
| `app/lib/photo_tagger_web/live/gallery_live/gallery_photo.ex` | Add `data-group-collapsed` attr to `<li>` |
| `app/assets/css/app.css` | Drag state visual feedback styles |

## Edge Cases

- **Same position drop**: JS hook skips push if `oldIndex === newIndex`; backend no-ops if order unchanged
- **Collapsed groups**: Filtered out by SortableJS `filter` option — can't be dragged
- **Multiselect mode**: Drag disabled via `data-sortable-enabled="false"` to avoid conflict with click selection
- **Cross-folder views**: Server guard rejects reordering between different folders
- **Sort direction (asc/desc)**: Irrelevant — the dragged photo takes the target's actual `manual_order` value
- **Pagination**: Works naturally — target photo's real `manual_order` is used, not visual index

## Verification

1. Start dev server: `docker compose -f docker-compose-dev.yml run dev_app bash` → `mix phx.server`
2. Navigate to `/admin` in browser
3. Verify sort is set to "manual"
4. Drag a photo to a new position → confirm it snaps to the new position and order persists on page reload
5. Switch to date sort → verify dragging is disabled (no drag cursor)
6. Enable multiselect → verify dragging is disabled
7. Collapse a group → verify collapsed group items can't be dragged
8. Run existing tests: `mix test` to verify no regressions
