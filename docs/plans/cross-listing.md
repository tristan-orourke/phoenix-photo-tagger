# Cross-Listing Feature Implementation Plan

## Summary

Add cross-listing functionality allowing photos to appear in multiple folders without duplicating files. Cross-listings are full database entries with independent metadata, referencing an original photo's files.

## Key Design Decisions

- **Name handling**: Copy exact name (unique constraint scoped to folder allows this)
- **Public visibility**: Cross-listings visible to public if marked public
- **File deletion**: Delete files immediately when original deleted (cascade removes cross-listings first)
- **Move validation**: Error if moving original to folder with its cross-listing (user must manually remove)
- **Bulk support**: Include bulk cross-listing in multi-photo selection

## Implementation Phases

### Phase 1: Database & Core Logic

**Migration** (`priv/repo/migrations/XXXXXX_add_original_photo_id_to_photos.exs`):
```elixir
alter table(:photos) do
  add :original_photo_id, references(:photos, on_delete: :delete_all), null: true
end
create index(:photos, [:original_photo_id])
```

**Schema** (`lib/photo_tagger/gallery/photo.ex`):
- Add `field :original_photo_id, :id`
- Add `belongs_to :original_photo, Photo`
- Add `has_many :cross_listings, Photo, foreign_key: :original_photo_id`

**Gallery Context** (`lib/photo_tagger/gallery.ex`):
- `create_cross_listing(photo, target_folder_id)` - copy metadata, tags, set original_photo_id
- `remove_cross_listing(photo)` - delete db record only, validate is cross-listing
- `is_cross_listing?(photo)` - check original_photo_id != nil
- `get_cross_listings(photo)` - list cross-listings of an original
- Modify `delete_photo/1` - cascade handles cross-listings, then delete files
- Modify `update_photo/2` - return `{:error, :cross_listing_exists_in_target_folder}` if conflict

### Phase 2: URL Generation

**ImageUploader** (`lib/photo_tagger/uploaders/image_uploader.ex`):
- Update `storage_dir/2` to use original's folder for cross-listings
- Check for `original_photo.folder` or `original_photo_id` in scope

**Preloading** - Update queries to include:
```elixir
|> Repo.preload([:folder, :tags, :cross_listings, original_photo: :folder])
```

### Phase 3: UI - Display

**Photo info panel** (`lib/photo_tagger_web/live/gallery_live/main.ex`, ~line 740):

After public/private badge, add cross-listing badge:
```heex
<p :if={@is_admin and is_cross_listing?(@photo)} class="text-sm px-2 py-0.5 rounded-full border text-purple-600 border-purple-600">
  cross-listed from <.link ...>{@photo.original_photo.folder.name}</.link>
</p>
```

For originals, show cross-listing links:
```heex
<div :if={@is_admin and has_cross_listings?(@photo)}>
  Cross-listed in: [links to each cross-listing in its folder]
</div>
```

**Delete section** (~line 904):
- Cross-listed: "Remove cross-listing" button (orange)
- Original with cross-listings: List folders, "Delete photo and all cross-listings" button

### Phase 4: UI - Single Photo Actions

**Edit panel** - Add after existing fields:
- Folder selector to create new cross-listing
- List current cross-listings with links

**Event handlers**:
- `handle_event("create_cross_listing", ...)` - call Gallery.create_cross_listing
- `handle_event("remove_cross_listing", ...)` - call Gallery.remove_cross_listing
- Update `handle_event("update_photo", ...)` - handle `:cross_listing_exists_in_target_folder` error

### Phase 5: Bulk Cross-Listing

**Multi-photo selection panel** (`main.ex`, in `multi_photo_selection/1`):
- Add folder selector for bulk cross-listing
- Note that only originals will be cross-listed

**Event handler**:
- `handle_event("create_cross_listing_bulk", ...)` - filter to originals, create cross-listings, report results

### Phase 6: Upload Integration

**Upload form** (`lib/photo_tagger_web/controllers/photo_html/new.html.heex`):
- Add multi-select for additional folders

**PhotoController** (`lib/photo_tagger_web/controllers/photo_controller.ex`):
- Update `create/2` to handle `cross_list_folders` param
- After creating photo, call `create_cross_listing` for each additional folder

## Critical Files

| File | Changes |
|------|---------|
| `priv/repo/migrations/` | New migration |
| `lib/photo_tagger/gallery/photo.ex` | Schema changes |
| `lib/photo_tagger/gallery.ex` | Core logic functions |
| `lib/photo_tagger/uploaders/image_uploader.ex` | URL generation for cross-listings |
| `lib/photo_tagger_web/live/gallery_live/main.ex` | UI components and event handlers |
| `lib/photo_tagger_web/controllers/photo_controller.ex` | Upload handling |
| `lib/photo_tagger_web/controllers/photo_html/new.html.heex` | Upload form |
| `test/photo_tagger/gallery_test.exs` | Unit tests |
| `test/photo_tagger_web/live/gallery_live_test.exs` | LiveView tests |

## Verification

1. **Unit tests**: Run `mix test test/photo_tagger/gallery_test.exs`
2. **LiveView tests**: Run `mix test test/photo_tagger_web/live/gallery_live_test.exs`
3. **Manual testing**:
   - Create cross-listing from photo edit panel
   - Verify badge and links display correctly
   - Verify cross-listing URLs resolve to original's files
   - Test remove cross-listing
   - Test delete original cascades to cross-listings
   - Test move original to cross-listed folder shows error
   - Test bulk cross-listing from multi-select
   - Test upload with cross-listing folders
