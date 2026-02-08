# Drag-and-Drop Photo Reordering Implementation

## Overview
This implementation adds drag-and-drop functionality to the admin photo gallery, allowing administrators to reorder photos by dragging them to new positions. The reordering updates the `manual_order` field in the database and persists changes immediately.

## Implementation Details

### 1. Frontend (JavaScript)

#### SortableJS Integration
- **File**: `app/assets/js/sortable.js`
- **Library**: SortableJS v1.15.3 (imported via CDN ESM)
- **Hook**: `SortableHook` - LiveView hook that manages drag-and-drop behavior

**Key Features**:
- Only enabled in admin mode (checked via `data-sortable-enabled` attribute)
- Visual feedback during drag: ghost, chosen, and drag CSS classes
- Prevents unnecessary operations when photo doesn't move
- Correctly identifies target photo based on drag direction:
  - Moving down/right: takes position of previous sibling
  - Moving up/left: takes position of next sibling
  - Special handling for "first" and "last" positions

#### Hook Registration
- **File**: `app/assets/js/app.js`
- Imported and registered as `SortableHook` in LiveSocket hooks

### 2. Backend (Elixir)

#### Gallery Context Function
- **File**: `app/lib/photo_tagger/gallery.ex`
- **Function**: `reorder_photo_to_position/2`

**Parameters**:
- `photo_id`: ID of the photo being dragged
- `target_photo_id`: ID of the target photo (or "first"/"last" strings)

**Logic**:
1. Fetches the dragged photo and its current `manual_order`
2. Determines target order based on target_photo_id:
   - "first" → order = 1
   - "last" → order = max + 1 (next available)
   - Photo ID → uses that photo's manual_order
3. Uses `Ecto.Multi` to coordinate:
   - `reorder_others`: Shifts other photos' manual_order values
   - `update_photo`: Updates dragged photo to target order
4. Returns `{:ok, photo}` or `{:error, changeset}`

**Reordering Logic** (via existing `reorder_photos_for_insert/3`):
- Moving to earlier position (old_order > target): Shifts photos in [target, old) up by 1
- Moving to later position (old_order < target): Shifts photos in (old, target] down by 1

#### LiveView Event Handler
- **File**: `app/lib/photo_tagger_web/live/gallery_live/main.ex`
- **Event**: `"reorder_photo"`

**Handler Logic**:
1. Receives `photo_id` and `target_photo_id` from JavaScript
2. Calls `Gallery.reorder_photo_to_position/2`
3. On success: Reloads photos to reflect new order
4. On error: Shows flash error message

### 3. UI Components

#### Gallery Panel Update
- **File**: `app/lib/photo_tagger_web/live/gallery_live/gallery_panel.ex`
- Added hook attachment to gallery grid `<ul>` element
- Added `id="gallery-grid"` for hook mounting
- Added `phx-hook="SortableHook"` when `is_admin` is true
- Added `data-sortable-enabled` attribute for JavaScript filtering

#### CSS Styling
- **File**: `app/assets/css/app.css`

**Classes Added**:
- `.sortable-ghost`: Semi-transparent with light blue background (dropped position preview)
- `.sortable-chosen`: Grabbing cursor during drag
- `.sortable-drag`: Slight opacity and rotation during drag
- Dynamic cursor styles: `grab` on hover, `grabbing` when active (admin mode only)

### 4. Tests

#### Test Coverage
- **File**: `app/test/photo_tagger/gallery_test.exs`

**Test Cases**:
1. `reorder_photo_to_position/2 moves photo to target photo's position`
   - Verifies photo takes target's order
   - Confirms other photos shift correctly
   
2. `reorder_photo_to_position/2 with 'first' moves photo to beginning`
   - Tests special "first" position
   - Verifies photos shift up
   
3. `reorder_photo_to_position/2 with 'last' moves photo to end`
   - Tests special "last" position
   - Verifies photos shift down

## User Experience

### Visual Feedback
1. **Hover**: Cursor changes to `grab` when hovering over photos (admin only)
2. **Drag Start**: Cursor changes to `grabbing`, photo gets `chosen` styling
3. **Dragging**: Ghost element shows where photo will be dropped
4. **Drop**: Photo instantly moves to new position, order updates persist

### Behavior
- Only works in admin view (requires `is_admin` flag)
- Works with manual sort order (photos must be sorted by manual_order)
- Real-time updates without page reload
- Maintains consistency across multiple photos

## Edge Cases Handled

1. **No movement**: If dragged and dropped in same position, no server request
2. **First position**: Handled with special "first" identifier
3. **Last position**: Handled with special "last" identifier
4. **Transaction safety**: Uses Ecto.Multi to ensure atomicity
5. **Non-admin views**: Hook not attached, no drag functionality

## Future Enhancements

Potential improvements:
- Optimistic UI updates (update DOM immediately, then sync with server)
- Batch reordering (drag multiple selected photos)
- Undo/redo functionality
- Animation smoothing for shifted photos
- Touch device support testing

## Testing Instructions

To manually test:
1. Start the Phoenix server in dev mode
2. Navigate to an admin gallery view (e.g., `/admin`)
3. Ensure photos are sorted by manual order
4. Click and drag a photo to a new position
5. Verify the photo moves and order persists
6. Check that other photos shift appropriately
7. Refresh page to confirm persistence

To run automated tests:
```bash
docker compose -f docker-compose-dev.yml run dev_app bash -c "cd app && mix test test/photo_tagger/gallery_test.exs"
```
