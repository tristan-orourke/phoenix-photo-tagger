<!-- dd7efa69-3802-4010-b946-515329334999 59d65968-b3a9-46d4-8f3b-091bad7de462 -->
# Photo Visibility Scheduling System Implementation Plan

## Overview

This plan implements a comprehensive photo visibility scheduling system with multiple folder types, manual ordering, and automated scheduling. The implementation will add database columns, update visibility logic, add folder type management, implement sorting options, and create UI for scheduling controls.

## Database Migrations

### 1. Photos Table Changes

- Add `public_at` (utc_datetime, nullable)
- Add `private_at` (utc_datetime, nullable)  
- Add `manual_order` (integer, nullable)

**Migration:** `add_photo_visibility_scheduling_fields.exs`

### 2. Folders Table Changes

- Add `folder_type` (string, default: "normal") with values: normal, weekly_single, daily_single
- Add `day_of_week` (integer, nullable, 0-6 for Sunday-Saturday)
- Add `current_index` (integer, nullable, default: 0)

**Migration:** `add_folder_type_fields.exs`

## Core Logic Changes

### 1. Photo Visibility Computation (`app/lib/photo_tagger/gallery.ex`)

- Create `compute_photo_visibility/1` function that determines visibility based on:
- `public_at` timestamp (photo is visible if current time >= public_at AND private_at is null or current time < private_at)
- `private_at` timestamp (photo is private if current time >= private_at)
- Folder type and day_of_week constraints
- For single-type folders: check current_index matches photo position in manual_order queue
- Update `only_public_photos/1` to use new visibility logic
- Update `list_photos_by_folder/2` to apply folder-type-specific filtering

### 2. Photo Schema Updates (`app/lib/photo_tagger/gallery/photo.ex`)

- Add fields: `public_at`, `private_at`, `manual_order`
- Update `changeset_create/2` and `changeset_update/2` to include new fields
- Add function to set `manual_order` on upload (max + 1 or total count)

### 3. Folder Schema Updates (`app/lib/photo_tagger/gallery/folder.ex`)

- Add fields: `folder_type`, `day_of_week`, `current_index`
- Update `changeset/2` to validate folder_type enum and day_of_week range
- Add validation: day_of_week required for daily/weekly/single types

### 4. Visibility Toggle Logic (`app/lib/photo_tagger/gallery.ex`)

- Update photo visibility toggle to set:
- When making public: `public_at = now()`, `private_at = null`
- When making private: `private_at = now()`, `public_at = null`
- Ensure this works for all folder types
- Remove all references to `is_public` field

### 5. Folder Type Query Logic (`app/lib/photo_tagger/gallery.ex`)

- `list_photos_by_folder/2` enhancements:
- **normal**: Standard visibility check
- **daily**: Filter by day_of_week matching current day
- **weekly**: Filter by week matching current week (based on public_at/private_at)
- **weekly_single**: Show only photo at current_index in manual_order queue
- **daily_single**: Show only photo at current_index in manual_order queue, filtered by day_of_week

### 6. Sorting Implementation (`app/lib/photo_tagger/gallery.ex`)

- Add `list_photos_by_folder_sorted/3` with sort_mode parameter:
- `:upload_timestamp` (default for admin)
- `:visibility_date` (default for public, sort by public_at)
- `:manual_order` (sort by manual_order)
- Update all list functions to accept sort_mode option

### 7. Manual Order Management (`app/lib/photo_tagger/gallery.ex`)

- Add `update_photo_manual_order/2` function
- Add `reorder_photos/2` function for batch updates
- On photo upload: set manual_order = max(manual_order) + 1 or total count

## Scheduled Tasks

### 1. Index Increment Task (`app/lib/photo_tagger/scheduler.ex`)

- Create new scheduler module using Oban or Quantum
- Daily task: Increment `current_index` for `daily_single` folders
- Weekly task: Increment `current_index` for `weekly_single` folders
- Wrap-around logic when index exceeds queue length

**Dependency:** Add Oban or Quantum to `mix.exs`

## UI Updates

### 1. Photo Edit Form (`app/lib/photo_tagger_web/live/gallery_live/main.ex`)

- Add `public_at` datetime input field
- Add `private_at` datetime input field
- Show scheduling controls based on folder type:
- normal: Show datepicker selection for both inputs
- Single types: Show queue position indicator

### 2. Folder Management (`app/lib/photo_tagger_web/controllers/folder_controller.ex` or LiveView)

- Add folder type dropdown (normal, daily, weekly, weekly_single, daily_single)
- Add day_of_week selector (for applicable types)
- Show current_index for single-type folders

### 3. Admin Gallery Drag-and-Drop (`app/lib/photo_tagger_web/live/gallery_live/main.ex`)

- Add SortableJS via LiveView hooks
- Implement `phx-hook` for drag-and-drop
- Handle `reorder_photos` event to update manual_order values
- Update UI to reflect new order

### 4. Admin gallery view (`app/lib/photo_tagger_web/live/gallery_live/main.ex`)

- For single-type folders: highlight the currently visible photo in the gallery view
- for normal type folders: highlight all public folders in the gallery view

## Files to Modify

1. **Migrations:**

- `app/priv/repo/migrations/YYYYMMDDHHMMSS_add_photo_visibility_scheduling_fields.exs`
- `app/priv/repo/migrations/YYYYMMDDHHMMSS_add_folder_type_fields.exs`

2. **Schemas:**

- `app/lib/photo_tagger/gallery/photo.ex`
- `app/lib/photo_tagger/gallery/folder.ex`

3. **Context:**

- `app/lib/photo_tagger/gallery.ex`

4. **LiveView:**

- `app/lib/photo_tagger_web/live/gallery_live/main.ex`

5. **Dependencies:**

- `app/mix.exs` (add Oban or Quantum)

6. **Application:**

- `app/lib/photo_tagger/application.ex` (start scheduler)

7. **New Files:**

- `app/lib/photo_tagger/scheduler.ex` (scheduled tasks)

## Implementation Order

1. Database migrations for photos and folders
2. Schema updates (Photo and Folder)
3. Core visibility computation logic
4. Folder type query logic
5. Manual order management
6. Sorting implementation
7. Scheduled tasks setup
8. UI updates (photo form, folder management)
9. Drag-and-drop implementation
10. Weekly/daily scheduling UI

## Notes

- `is_public` field will be completely removed and replaced by `public_at`/`private_at` timestamps
- Migration will set `public_at = now()` for all photos where `is_public = true` before removing the column
- All existing photos will need `manual_order` populated (migration can set based on inserted_at)
- Default folder_type for existing folders will be "normal"
- Single-type folders (weekly_single, daily_single) require at least one photo with manual_order set
- Both single-type folders use identical query logic - only difference is increment frequency (daily vs weekly)
- Cron job requires Docker image to have cron installed and configured
- `public_at` and `private_at` use date pickers (datetime-local input)
- When making public: `public_at = now()`, `private_at = null`
- When making private: `private_at = now()`, `public_at = null`

### To-dos

- [ ] Create migration to add visible_at, private_at, and manual_order columns to photos table
- [ ] Create migration to add folder_type, day_of_week, and current_index columns to folders table
- [ ] Update Photo schema and changesets to include new fields
- [ ] Update Folder schema and changesets to include new fields with validation
- [ ] Implement compute_photo_visibility/1 function and update only_public_photos/1
- [ ] Update list_photos_by_folder/2 to handle different folder types (daily, weekly, single types)
- [ ] Implement manual_order management (set on upload, update functions)
- [ ] Add sorting modes (upload_timestamp, visibility_date, manual_order) to photo queries
- [ ] Update photo visibility toggle to set visible_at/private_at timestamps
- [ ] Add Oban or Quantum dependency and create scheduler module for index increments
- [ ] Add visible_at and private_at fields to photo edit form in LiveView
- [ ] Add folder type selector and day_of_week input to folder management UI
- [ ] Implement drag-and-drop reordering with SortableJS hooks and manual_order updates
- [ ] Add weekly/daily scheduling controls in sidebar for photo visibility management