# Cross-Listing Feature Specification

## Overview

Cross-listing allows a single uploaded photo file to appear in multiple folders without duplicating the file on disk. The original photo maintains its file storage location, while cross-listed entries are database-only references that can have their own metadata (tags, visibility, description, etc.).

## Core Concepts

### Original vs Cross-Listed Photos

- **Original photo**: The photo entry that owns the actual image file. Has `original_photo_id = NULL`.
- **Cross-listed photo**: A database entry referencing an original. Has `original_photo_id` pointing to the original. Does not own any files.

### Key Behaviors

1. Cross-listed entries are full Photo records with their own:
   - `name`, `description`, `notes`, `group`
   - `is_public` visibility
   - `folder_id` (must differ from original)
   - `tags` associations
   - `manual_order`

2. Cross-listed entries do NOT have their own files - they reference the original's files for URL generation.

3. Metadata is **not synchronized** between original and cross-listings. Each entry is independent after creation.

---

## Database Changes

### Schema: Photo

Add a new nullable field to the `photos` table:

```elixir
field :original_photo_id, :id  # NULL for originals, references photos(id) for cross-listings
```

**Migration:**

```elixir
alter table(:photos) do
  add :original_photo_id, references(:photos, on_delete: :delete_all), null: true
end

create index(:photos, [:original_photo_id])
```

**Associations in Photo schema:**

```elixir
belongs_to :original_photo, Photo, foreign_key: :original_photo_id
has_many :cross_listings, Photo, foreign_key: :original_photo_id
```

**Constraints:**
- `original_photo_id` must reference a photo where `original_photo_id IS NULL` (can't cross-list a cross-listing)
- A photo cannot be cross-listed into the same folder as its original (handled at application level)

---

## Gallery Context API

### New Functions

#### `create_cross_listing/2`

Creates a cross-listing of an original photo in a target folder.

```elixir
@spec create_cross_listing(Photo.t(), folder_id :: integer()) :: {:ok, Photo.t()} | {:error, Ecto.Changeset.t()}
def create_cross_listing(original_photo, target_folder_id)
```

**Behavior:**
1. Validate `original_photo` is not itself a cross-listing
2. Validate `target_folder_id` differs from original's folder
3. Check no existing cross-listing of this photo in target folder
4. Copy metadata from original: `name`, `description`, `notes`, `group`, `is_public`, `image`, `image_last_modified`
5. Copy tags from original
6. Set `original_photo_id` to original's id
7. Set `folder_id` to target folder
8. Assign `manual_order` (append to end of target folder)

#### `remove_cross_listing/1`

Removes a cross-listed photo entry (database only, no file deletion).

```elixir
@spec remove_cross_listing(Photo.t()) :: {:ok, Photo.t()} | {:error, :not_a_cross_listing}
def remove_cross_listing(cross_listed_photo)
```

**Behavior:**
1. Validate photo is a cross-listing (`original_photo_id != nil`)
2. Delete the database record only (no file operations)
3. Return error if attempting on an original photo

#### `get_cross_listings/1`

Returns all cross-listings of an original photo.

```elixir
@spec get_cross_listings(Photo.t()) :: [Photo.t()]
def get_cross_listings(original_photo)
```

#### `is_cross_listing?/1`

```elixir
@spec is_cross_listing?(Photo.t()) :: boolean()
def is_cross_listing?(photo), do: photo.original_photo_id != nil
```

#### `is_original_with_cross_listings?/1`

```elixir
@spec is_original_with_cross_listings?(Photo.t()) :: boolean()
def is_original_with_cross_listings?(photo)
```

Returns true if photo is an original that has cross-listings.

### Modified Functions

#### `delete_photo/1`

Update to handle cross-listing cascade:

**For original photos with cross-listings:**
1. Delete all cross-listing database entries first
2. Delete original's files
3. Delete original's database entry

**For cross-listed photos:**
- Call `remove_cross_listing/1` instead (no file deletion)

#### `update_photo/2`

When moving a photo to a new folder:
1. Check if a cross-listing of this photo already exists in the target folder
2. If yes, return an error: `{:error, :cross_listing_exists_in_target_folder}`
3. User must manually remove the cross-listing before moving the original

#### Query functions

All photo listing functions should work transparently with cross-listings:
- `list_photos_by_folder/2` - returns both originals and cross-listings in the folder
- `list_photos_by_tags/2` - includes cross-listings matching tags
- No special handling needed since cross-listings are full Photo records

---

## URL Generation

### ImageUploader Changes

Modify URL generation to use the original's folder for cross-listed photos:

```elixir
def storage_dir(_version, {_file, scope}) do
  folder_name = get_folder_name(scope)
  "uploads/images/#{folder_name}/"
end

defp get_folder_name(%{original_photo: %Photo{folder: folder}}) when not is_nil(folder) do
  folder.name
end
defp get_folder_name(%{original_photo_id: original_id}) when not is_nil(original_id) do
  # Fallback: query for original's folder
  Photo |> Repo.get!(original_id) |> Repo.preload(:folder) |> Map.get(:folder) |> Map.get(:name)
end
defp get_folder_name(%{folder: %{name: name}}), do: name
defp get_folder_name(%{folder_id: folder_id}) do
  Folder |> Repo.get!(folder_id) |> Map.get(:name)
end
```

**Preloading requirement:** When displaying cross-listed photos, ensure `original_photo.folder` is preloaded for efficient URL generation.

### Preload Strategy

Add to relevant queries:
```elixir
|> Repo.preload([original_photo: :folder])
```

Or use a helper:
```elixir
def preload_for_display(photos) do
  Repo.preload(photos, [:folder, :tags, original_photo: :folder])
end
```

---

## UI Changes

### Admin Photo Info Panel

#### Cross-Listing Badge

After the public/private badge (line ~740 in main.ex), add:

```heex
<p :if={@is_admin and is_cross_listing?(@photo)}
   class="text-sm px-2 py-0.5 rounded-full border text-purple-600 border-purple-600">
  cross-listed from
  <.link patch={Util.build_url(@photo.original_photo.folder.name, [@photo.original_photo.id], @tags, @exclude_tags, @is_admin)}
         class="underline hover:text-purple-800">
    {@photo.original_photo.folder.name}
  </.link>
</p>
```

#### Cross-Listings List (for originals)

Below the folder/badge row, show cross-listing links for original photos:

```heex
<div :if={@is_admin and has_cross_listings?(@photo)} class="mt-2 text-sm text-zinc-600">
  <span class="font-medium">Cross-listed in: </span>
  <%= for {listing, index} <- Enum.with_index(@photo.cross_listings) do %>
    <.link patch={Util.build_url(listing.folder.name, [listing.id], @tags, @exclude_tags, @is_admin)}
           class="text-purple-600 hover:text-purple-800 underline">
      {listing.folder.name}
    </.link><%= if index < length(@photo.cross_listings) - 1, do: ", " %>
  <% end %>
</div>
```

#### Delete Section

Replace the current delete section with conditional content:

**For cross-listed photos:**
```heex
<:item title="Remove Cross-listing" :if={@is_admin and is_cross_listing?(@photo)}>
  <.form
    phx-submit="remove_cross_listing"
    for={Component.to_form(%{"photo_id" => @photo.id})}
    onsubmit="return confirm('Remove this cross-listing? The original photo will remain in its folder.')"
  >
    <input class="hidden" type="text" name="photo_id" value={@photo.id} />
    <.button class="bg-orange-600 hover:bg-orange-700">Remove cross-listing</.button>
  </.form>
</:item>
```

**For original photos with cross-listings:**
```heex
<:item title="Delete" :if={@is_admin and not is_cross_listing?(@photo)}>
  <div :if={has_cross_listings?(@photo)} class="mb-3 text-sm text-zinc-600">
    <p class="font-medium">Also cross-listed in:</p>
    <ul class="list-disc ml-4 mt-1">
      <%= for listing <- @photo.cross_listings do %>
        <li>
          <.link patch={Util.build_url(listing.folder.name, [listing.id], [], [], @is_admin)}
                 class="text-blue-600 hover:underline">
            {listing.folder.name}
          </.link>
        </li>
      <% end %>
    </ul>
  </div>
  <.form
    phx-submit="delete_photo"
    for={Component.to_form(%{"photo_id" => @photo.id})}
    onsubmit={"return confirm('#{delete_confirmation_message(@photo)}')"}
  >
    <input class="hidden" type="text" name="photo_id" value={@photo.id} />
    <.button class="bg-red-600 hover:bg-red-900">
      {delete_button_text(@photo)}
    </.button>
  </.form>
</:item>
```

**Helper functions:**
```elixir
defp delete_button_text(photo) do
  if has_cross_listings?(photo) do
    "Delete photo and all cross-listings"
  else
    "Delete"
  end
end

defp delete_confirmation_message(photo) do
  if has_cross_listings?(photo) do
    count = length(photo.cross_listings)
    "This will permanently delete this photo and #{count} cross-listing(s). Continue?"
  else
    "Are you sure you want to permanently delete this photo?"
  end
end
```

### Photo Edit Panel

Add cross-listing management to the edit form:

```heex
<:item title="Cross-list to folder" :if={@is_admin and not is_cross_listing?(@photo)}>
  <.form for={Component.to_form(%{"photo_id" => @photo.id, "folder_id" => ""})}
         phx-submit="create_cross_listing">
    <input class="hidden" type="text" name="photo_id" value={@photo.id} />
    <div class="flex gap-2">
      <select name="folder_id" class="rounded-lg text-sm">
        <option value="">Select folder...</option>
        <%= for folder <- available_cross_list_folders(@photo, @all_folders) do %>
          <option value={folder.id}>{folder.name}</option>
        <% end %>
      </select>
      <.button type="submit">Cross-list</.button>
    </div>
  </.form>

  <div :if={not Enum.empty?(@photo.cross_listings)} class="mt-3">
    <p class="text-sm font-medium text-zinc-600 mb-1">Current cross-listings:</p>
    <ul class="text-sm">
      <%= for listing <- @photo.cross_listings do %>
        <li class="flex items-center gap-2">
          <.link patch={Util.build_url(listing.folder.name, [listing.id], [], [], @is_admin)}
                 class="text-blue-600 hover:underline">
            {listing.folder.name}
          </.link>
        </li>
      <% end %>
    </ul>
  </div>
</:item>
```

**Helper:**
```elixir
defp available_cross_list_folders(photo, all_folders) do
  existing_folder_ids = [photo.folder_id | Enum.map(photo.cross_listings, & &1.folder_id)]
  Enum.reject(all_folders, &(&1.id in existing_folder_ids))
end
```

### Upload Form

Add optional cross-listing during upload:

After folder selection, add multi-select for additional folders:

```heex
<div class="mt-4">
  <label class="block text-sm font-medium text-zinc-700">
    Also cross-list to (optional):
  </label>
  <select name="photo[cross_list_folders][]" multiple class="mt-1 rounded-lg w-full h-24">
    <%= for folder <- @folders do %>
      <option value={folder.id}>{folder.name}</option>
    <% end %>
  </select>
  <p class="text-xs text-zinc-500 mt-1">Hold Ctrl/Cmd to select multiple folders</p>
</div>
```

### Multi-Photo Selection Panel (Bulk Cross-Listing)

Add cross-listing option to the multi-photo selection panel (after existing bulk operations):

```heex
<:item title="Cross-list to folder" :if={@is_admin}>
  <.form for={Component.to_form(%{"folder_id" => ""})} phx-submit="create_cross_listing_bulk">
    <div class="flex gap-2">
      <select name="folder_id" class="rounded-lg text-sm">
        <option value="">Select folder...</option>
        <%= for folder <- available_bulk_cross_list_folders(@photos, @all_folders) do %>
          <option value={folder.id}>{folder.name}</option>
        <% end %>
      </select>
      <.button type="submit">Cross-list all</.button>
    </div>
  </.form>
  <p class="text-xs text-zinc-500 mt-1">
    Cross-listings will only be created for original photos (not existing cross-listings)
  </p>
</:item>
```

**Helper:**
```elixir
defp available_bulk_cross_list_folders(photos, all_folders) do
  # Exclude folders where ALL selected originals already exist (as original or cross-listing)
  original_photos = Enum.reject(photos, &is_cross_listing?/1)

  Enum.filter(all_folders, fn folder ->
    Enum.any?(original_photos, fn photo ->
      photo.folder_id != folder.id and
        not Enum.any?(photo.cross_listings, &(&1.folder_id == folder.id))
    end)
  end)
end
```

---

## LiveView Event Handlers

### New Events

#### `handle_event("create_cross_listing", ...)`

```elixir
def handle_event("create_cross_listing", %{"photo_id" => photo_id, "folder_id" => folder_id}, socket) do
  photo = Gallery.get_photo!(photo_id, include_private: true)

  case Gallery.create_cross_listing(photo, String.to_integer(folder_id)) do
    {:ok, cross_listing} ->
      socket
      |> put_flash(:info, "Photo cross-listed to #{cross_listing.folder.name}")
      |> assign(:photo, Gallery.get_photo!(photo_id, include_private: true) |> Repo.preload(...))
      |> noreply()

    {:error, changeset} ->
      socket
      |> put_flash(:error, "Failed to create cross-listing: #{error_message(changeset)}")
      |> noreply()
  end
end
```

#### `handle_event("create_cross_listing_bulk", ...)`

```elixir
def handle_event("create_cross_listing_bulk", %{"folder_id" => folder_id}, socket) do
  target_folder_id = String.to_integer(folder_id)

  # Filter to only original photos (skip cross-listings)
  originals = Enum.reject(socket.assigns.selected_photos, &Gallery.is_cross_listing?/1)

  results = Enum.map(originals, fn photo ->
    Gallery.create_cross_listing(photo, target_folder_id)
  end)

  success_count = Enum.count(results, &match?({:ok, _}, &1))
  error_count = Enum.count(results, &match?({:error, _}, &1))

  socket =
    case {success_count, error_count} do
      {0, _} ->
        put_flash(socket, :error, "No cross-listings created (photos may already exist in target folder)")
      {_, 0} ->
        put_flash(socket, :info, "Created #{success_count} cross-listing(s)")
      {_, _} ->
        put_flash(socket, :info, "Created #{success_count} cross-listing(s), #{error_count} skipped")
    end

  socket
  |> assign(:selected_photos, [])  # Clear selection
  |> noreply()
end
```

#### `handle_event("remove_cross_listing", ...)`

```elixir
def handle_event("remove_cross_listing", %{"photo_id" => photo_id}, socket) do
  photo = Gallery.get_photo!(photo_id, include_private: true)

  case Gallery.remove_cross_listing(photo) do
    {:ok, _} ->
      # Navigate back to folder or clear selection
      socket
      |> put_flash(:info, "Cross-listing removed")
      |> push_patch(to: Util.build_url(socket.assigns.folder, [], ...))
      |> noreply()

    {:error, :not_a_cross_listing} ->
      socket
      |> put_flash(:error, "Cannot remove - this is not a cross-listing")
      |> noreply()
  end
end
```

### Modified Events

#### `handle_event("update_photo", ...)`

Update error handling to show user-friendly message for cross-listing conflict:

```elixir
def handle_event("update_photo", %{"photo_id" => photo_id, "photo" => photo_params}, socket) do
  photo = Gallery.get_photo!(photo_id, include_private: true)

  case Gallery.update_photo(photo, photo_params) do
    {:ok, updated_photo} ->
      # existing success handling...

    {:error, :cross_listing_exists_in_target_folder} ->
      target_folder = Gallery.get_folder!(photo_params["folder_id"])
      socket
      |> put_flash(:error, "Cannot move: this photo is cross-listed in #{target_folder.name}. Remove the cross-listing first.")
      |> noreply()

    {:error, changeset} ->
      # existing error handling...
  end
end
```

#### `handle_event("delete_photo", ...)`

No changes needed - `Gallery.delete_photo/1` handles the cascade logic internally.

---

## Edge Cases & Validation

### Preventing Invalid States

1. **Cannot cross-list a cross-listing**: `create_cross_listing/2` checks `original_photo_id == nil`

2. **Cannot cross-list to same folder**: Validation ensures `target_folder_id != photo.folder_id`

3. **Cannot duplicate cross-listing**: Check for existing cross-listing of same original in target folder

4. **Moving original to cross-listed folder**: `update_photo/2` returns an error; user must manually remove the cross-listing first

5. **Deleting folder with cross-listings**: Cascade delete handles this (cross-listings in the folder are deleted, but originals elsewhere remain)

### Name Conflicts

Cross-listings may have name conflicts in their target folder. Options:

**Option A (Recommended):** Allow duplicate names across original and cross-listings in different folders. The unique constraint is already scoped to `[name, folder_id]`, so this works automatically.

**Option B:** Auto-rename cross-listings (e.g., `photo.jpg` -> `photo (cross-listed).jpg`)

---

## Preloading Requirements

Ensure these preloads are added to photo queries:

```elixir
# For displaying a single photo with cross-listing info
|> Repo.preload([:folder, :tags, :cross_listings, original_photo: :folder])

# For listing photos (minimal preloads for URL generation)
|> Repo.preload([:folder, :tags, original_photo: :folder])
```

---

## Testing Considerations

### Unit Tests (Gallery Context)

1. `create_cross_listing/2`
   - Successfully creates cross-listing with copied metadata
   - Copies tags from original
   - Fails when photo is already a cross-listing
   - Fails when target folder is same as original
   - Fails when cross-listing already exists in target folder

2. `remove_cross_listing/1`
   - Successfully removes cross-listing (no file deletion)
   - Fails on original photo

3. `delete_photo/1`
   - Deletes original and all cross-listings
   - Removes files only for originals

4. `update_photo/2` (move to folder)
   - Returns error when target folder has a cross-listing of this photo
   - Succeeds after cross-listing is manually removed

### LiveView Tests

1. Cross-listing badge displays correctly with link to original
2. Original photo shows links to all cross-listings
3. Delete button text changes based on cross-listings
4. Create cross-listing event works
5. Remove cross-listing event works
6. Cross-listing folder selector excludes current and existing folders
7. Bulk cross-listing creates entries for all selected originals
8. Bulk cross-listing skips photos that are already cross-listings

---

## Implementation Order

1. **Phase 1: Database & Core Logic**
   - Add migration for `original_photo_id`
   - Update Photo schema with associations
   - Implement `create_cross_listing/2`, `remove_cross_listing/1`
   - Update `delete_photo/1` for cascade
   - Update `update_photo/2` for move conflict validation
   - Add unit tests

2. **Phase 2: URL Generation**
   - Update ImageUploader to handle cross-listings
   - Add preload helpers
   - Update existing queries with new preloads

3. **Phase 3: UI - Display**
   - Add cross-listing badge with link to original
   - Add cross-listings list for originals with links
   - Update delete section with conditional content

4. **Phase 4: UI - Single Photo Actions**
   - Add create cross-listing form and event handler
   - Add remove cross-listing event handler
   - Add LiveView tests

5. **Phase 5: Bulk Cross-Listing**
   - Add bulk cross-listing to multi-photo selection panel
   - Add `create_cross_listing_bulk` event handler

6. **Phase 6: Upload Integration**
   - Add multi-folder selection to upload form
   - Update PhotoController.create to handle cross-listing on upload

---

## Design Decisions

1. **Name handling**: Copy exact name from original. The unique constraint `[name, folder_id]` allows same name in different folders.

2. **Public visibility**: Cross-listings are visible to public users if marked public and in a public/unlisted folder (same rules as regular photos).

3. **Upload integration**: Include multi-folder selection in initial release (Phase 5).

4. **Bulk operations**: Support bulk cross-listing - allow cross-listing multiple selected photos to a folder at once.

5. **Cross-listing from cross-listing view**: The "cross-list to folder" UI only appears on originals, not on cross-listed photos.

6. **Tag sync**: No sync option - each entry is fully independent after creation.
