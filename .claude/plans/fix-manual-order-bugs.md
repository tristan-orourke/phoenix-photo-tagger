# Fix Manual Order Bugs

## Overview

This plan addresses three bugs in the manual ordering feature for photos in the gallery.

## Bug 1: Sort Parameter Not Preserved When Selecting Photos

**Problem:** Clicking to select a photo loses the `sort=manual` URL parameter, reverting to default date sorting.

**Root Cause:** `handle_single_photo_select/2` and `handle_multi_photo_select/2` in `main.ex` call `Util.build_url()` without passing the sort parameter.

**Files to Modify:**
- `app/lib/photo_tagger_web/live/gallery_live/main.ex`

**Changes:**

1. Update `handle_single_photo_select/2` (lines 1064-1076) to pass `socket.assigns.sort`:
```elixir
def handle_single_photo_select(photo_id, socket) do
  {:noreply,
   push_patch(socket,
     to:
       Util.build_url(
         socket.assigns.folder,
         [photo_id],
         socket.assigns.tags,
         socket.assigns.exclude_tags,
         socket.assigns.is_admin,
         nil,
         socket.assigns.sort
       )
   )}
end
```

2. Update `handle_multi_photo_select/2` (lines 1040-1062) similarly to pass `socket.assigns.sort`.

3. Update `handle_event("select_gallery_group", ...)` (lines 1188-1221) to also pass the sort parameter.

---

## Bug 2: No Logic to Reorder Photos When manual_order Conflicts

**Problem:** When setting a photo's `manual_order` to a value already used by another photo, duplicates occur. Expected behavior: shift other photos' orders to make room.

**Files to Modify:**
- `app/lib/photo_tagger/gallery.ex`

**Changes:**

1. Create a new function `reorder_photos_for_insert/3` that:
   - Takes `folder_id`, `target_order`, and optionally `old_order`
   - If `old_order` is nil: increment all photos with `manual_order >= target_order`
   - If `old_order > target_order` (moving down): increment photos in the range `[target_order, old_order)`
   - If `old_order < target_order` (moving up): decrement photos in the range `(old_order, target_order]`
   - Uses a single UPDATE query for efficiency

2. Modify `update_photo/2` to:
   - Detect when `manual_order` is being changed
   - Call `reorder_photos_for_insert/3` within the `Ecto.Multi` transaction before updating the photo
   - Only reorder photos in the same folder

**Implementation:**

```elixir
defp reorder_photos_for_insert(folder_id, target_order, old_order \\ nil) do
  import Ecto.Query

  query =
    cond do
      # New photo - shift everything at target and above
      is_nil(old_order) ->
        from(p in Photo,
          where: p.folder_id == ^folder_id and p.manual_order >= ^target_order,
          update: [inc: [manual_order: 1]]
        )

      # Moving down (from higher number to lower) - shift photos in [target, old) up by 1
      old_order > target_order ->
        from(p in Photo,
          where: p.folder_id == ^folder_id and p.manual_order >= ^target_order and p.manual_order < ^old_order,
          update: [inc: [manual_order: 1]]
        )

      # Moving up (from lower number to higher) - shift photos in (old, target] down by 1
      old_order < target_order ->
        from(p in Photo,
          where: p.folder_id == ^folder_id and p.manual_order > ^old_order and p.manual_order <= ^target_order,
          update: [inc: [manual_order: -1]]
        )

      # No change
      true ->
        nil
    end

  if query, do: Repo.update_all(query, []), else: {0, nil}
end
```

3. Add the reorder step to `update_photo/2`:

```elixir
def update_photo(%Photo{} = photo, attrs) do
  # ... existing attrs processing ...

  changeset = Photo.changeset_update(photo, attrs)
  photo = Repo.preload(photo, :folder)

  # Determine if manual_order is changing
  new_order = Map.get(attrs, "manual_order") || Map.get(attrs, :manual_order)
  old_order = photo.manual_order

  Ecto.Multi.new()
  |> Ecto.Multi.run(:reorder, fn _repo, _changes ->
    if new_order && new_order != old_order do
      reorder_photos_for_insert(photo.folder_id, new_order, old_order)
    end
    {:ok, :reordered}
  end)
  |> Ecto.Multi.update(:photo, changeset)
  |> Ecto.Multi.run(:update_file, fn _repo, changes ->
    # ... existing file update logic ...
  end)
  |> Repo.transaction()
end
```

---

## Bug 3: Gallery Not Refreshing After Order Change

**Problem:** After saving a photo with a new `manual_order`, the gallery doesn't re-sort to reflect the change.

**Files to Modify:**
- `app/lib/photo_tagger_web/live/gallery_live/main.ex`

**Changes:**

1. Update `handle_event("update_photo", ...)` (lines 1312-1333) to call `refresh_filtered_photos()` on success:

```elixir
case result do
  {:ok, _photo} ->
    {:noreply,
     assign(socket, :all_folders, Gallery.list_folders(include_private: is_admin))
     |> refresh_selected_photos()
     |> refresh_filtered_photos()  # ADD THIS LINE
     |> put_flash(:info, "Photo updated successfully.")}
```

2. Update `refresh_filtered_photos/1` (lines 1102-1148) to pass the `sort` parameter to all Gallery query functions:

```elixir
def refresh_filtered_photos(socket) do
  is_admin = socket.assigns.is_admin
  sort = socket.assigns.sort  # ADD THIS

  filtered_photos =
    case {socket.assigns.folder, socket.assigns.tags, socket.assigns.exclude_tags} do
      {nil, [], []} ->
        Gallery.list_photos(include_private: is_admin, sort: sort)

      {nil, tags, exclude_tags} ->
        Gallery.list_photos_by_tags(%{include: tags, exclude: exclude_tags},
          include_private: is_admin,
          sort: sort
        )

      {folder, [], []} ->
        Gallery.list_photos_by_folder(folder, include_private: is_admin, sort: sort)

      {folder, tags, exclude_tags} ->
        Gallery.list_photos_by_folder_and_tags(folder, %{include: tags, exclude: exclude_tags},
          include_private: is_admin,
          sort: sort
        )
    end
  # ... rest unchanged ...
end
```

---

## Testing

1. **Bug 1 Test:**
   - Set sort to "Manual order" in the gallery
   - Click on different photos
   - Verify the URL still contains `sort=manual` and gallery stays in manual order

2. **Bug 2 Test:**
   - Create photos with manual orders 1, 2, 3
   - Edit photo #3 and set manual_order to 1
   - Verify photos now have orders 1, 2, 3 (with #3 now first)
   - Verify no duplicate manual_order values exist

3. **Bug 3 Test:**
   - While sorting by manual order, edit a photo's manual_order
   - Save the form
   - Verify the gallery immediately shows the new order without page refresh

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `app/lib/photo_tagger_web/live/gallery_live/main.ex` | Pass sort param in photo select handlers; call refresh_filtered_photos after update; pass sort to Gallery queries |
| `app/lib/photo_tagger/gallery.ex` | Add reorder_photos_for_insert/3; integrate reordering into update_photo/2 |
