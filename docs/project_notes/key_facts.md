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

## Routes

- `/` - Public browsing (folders, photos, drift view)
- `/admin` - Full CRUD, folder/tag management, LiveDashboard

## Schemas

- `Photo` - Image attachment via Waffle, belongs to folder, many-to-many with tags
- `Tag` - Case-insensitive names (CITEXT)
- `Folder` - Contains photos, has `is_public` flag
- `PhotoTag` - Join table for photo-tag associations

## Testing Gotchas

### [2026-01-30] Tests using TempFileHelper must not run async

**Problem**: `TempFileHelper.setup_temp_storage/1` sets a global Application environment variable (`:waffle, :storage_dir_prefix`) that controls where Waffle stores uploaded files. When tests run with `async: true`, concurrent tests overwrite each other's storage directory settings, causing files to be created in the wrong location.

**Symptoms**: Intermittent test failures with "file not found" errors (`:enoent`), or assertions failing because file paths have different temp directory IDs than expected.

**Solution**: Any test file that uses `setup_temp_storage` must use `async: false`:
```elixir
use PhotoTagger.DataCase, async: false  # or PhotoTaggerWeb.ConnCase
```

**Affected test files**:
- `test/photo_tagger/gallery_file_operations_test.exs`
- `test/photo_tagger_web/controllers/photo_controller_test.exs`
- `test/photo_tagger_web/controllers/folder_controller_test.exs`
- `test/photo_tagger/gallery_test.exs` (already defaults to async: false)

### [2026-01-24] Manual debugging with `mix run -e` creates stale data

**Problem**: When debugging code using `mix run -e "..."` (without `MIX_ENV=test`), database records are created in the dev database. If the same database is shared with tests, or if `MIX_ENV=test mix run -e` is used, this creates persistent records that pollute test runs since they bypass Ecto sandbox isolation.

**Symptoms**: Tests fail with unexpected data (extra photos, folders, or tags appearing), unique constraint violations on hardcoded names like "test_folder".

**Solution**: After manual debugging that creates database records, reset the test database:
```bash
docker compose -f docker-compose-dev.yml run --rm dev_app bash -c 'MIX_ENV=test mix ecto.reset'
```

**Prevention**: When writing manual test scripts, use unique names (e.g., `"test_#{System.unique_integer([:positive])}"`) instead of hardcoded names like "test_folder".
