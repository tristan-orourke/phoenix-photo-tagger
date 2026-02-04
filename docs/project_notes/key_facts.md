# Key Project Facts

Essential information about the Photo Tagger project.

## Development Environment

- **Framework**: Phoenix 1.7 with LiveView
- **Language**: Elixir
- **Database**: PostgreSQL with Ecto
- **Image Handling**: Waffle for uploads and transformations
- **Styling**: Tailwind CSS

### Docker Development Setup

All development happens inside Docker containers. Mix commands must be run inside the container:

```bash
# Start container with bash shell
docker compose -f docker-compose-dev.yml run dev_app bash

# Run single command
docker compose -f docker-compose-dev.yml run dev_app <command>
```

**Dev server port**: 4001 (exposed via docker-compose-dev.yml)

## Database

- **Type**: PostgreSQL
- **CITEXT**: Used for case-insensitive tag names
- **Migrations**: Located in `app/priv/repo/migrations/`

## Image Uploads (Waffle)

- **Uploader**: `lib/photo_tagger/uploaders/image_uploader.ex`
- **Versions**: original, web, thumbnail
- **Storage path**: Based on folder name
- **File naming**: Based on photo metadata

## Core Architecture

- **Main context**: `lib/photo_tagger/gallery.ex` handles all photo/tag/folder operations
- **Phoenix app root**: `app/` directory
- **Public/private filtering**: Most functions accept `:include_private` option
- **File operations**: Use `Ecto.Multi` to coordinate DB changes with filesystem

## Photo Selection

- **Click metadata capture**: JavaScript in `app.js` captures `shift_key_pressed` and `ctrl_key_pressed` in LiveView click events
- **Selection tracking**: `last_selected_photo_id` tracked in socket assigns for shift-click range selection
- **Multi-select modes**: 
  - Single click: Select one photo
  - Ctrl+click or multiselect mode: Toggle individual photos
  - Shift+click (with ctrl or in multiselect mode): Select range from last selected to clicked photo
- **Collapsed groups**: When selecting a range that includes a collapsed group's representative photo, all photos in that group are included in the selection

## Routes

- `/` - Public browsing (folders, photos, drift view)
- `/admin` - Full CRUD, folder/tag management, LiveDashboard

## Schemas

- `Photo` - Image attachment via Waffle, belongs to folder, many-to-many with tags
- `Tag` - Case-insensitive names (CITEXT)
- `Folder` - Contains photos, has `is_public` flag
- `PhotoTag` - Join table for photo-tag associations
