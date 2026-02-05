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

### [2026-01-30] Phoenix LiveView testing best practices

**Phoenix LiveView 1.0+ does not support `view.assigns` access in tests**. The `Phoenix.LiveViewTest.View` struct only has these fields: `id`, `module`, `pid`, `proxy`, `endpoint` - no `assigns` field exists.

**Correct approach**: Test rendered HTML output instead of internal assigns.

**Pattern examples**:
```elixir
# Instead of: assert view.assigns.interval_ms == 5000
# Use: assert render(view) =~ ~r/data-interval-ms="5000"/

# Instead of: assert view.assigns.photo.id == photo.id
# Use: assert render(view) =~ photo.name
# Or: assert render(view) =~ ImageUploader.url({photo.image, photo}, :web_lg)
```

**Why this is better**:
- Tests verify what users actually see (behavioral testing)
- Tests remain stable when internal implementation changes
- Tests mirror real browser behavior

**Note**: While `:sys.get_state(view.pid)` can access process state, this is:
- Not documented or recommended by Phoenix
- Couples tests to implementation details
- Makes tests fragile and harder to maintain

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

### [2026-02-01] LiveView event parameters must use string keys and values

**Problem**: When using `render_click/3` or `render_change/3` in tests, parameters must match exactly what the browser sends - string keys and string values.

**Incorrect**:
```elixir
render_click(view, "change_page", %{pg: 2})
render_click(view, "select_photo", %{photo_id: photo.id, ctrl_key_pressed: false})
```

**Correct**:
```elixir
render_click(view, "change_page", %{"pg" => "2"})
render_click(view, "select_photo", %{"photo_id" => to_string(photo.id), "ctrl_key_pressed" => "false"})
```

**Why**: LiveView handlers pattern-match on string keys (e.g., `%{"pg" => pg}`), and functions like `Integer.parse/1` expect string arguments. Passing atoms or integers causes `FunctionClauseError`.

### [2026-02-01] LiveComponent events require element targeting

**Problem**: Events with `phx-target={@myself}` are handled by the LiveComponent, not the parent LiveView. Using `render_click(view, "event_name", params)` sends to the parent, which doesn't handle the event.

**Incorrect**:
```elixir
render_click(view, "select_index", %{"index" => "T"})
```

**Correct**:
```elixir
view |> element("#index-selectors button", "T") |> render_click()
```

**Pattern**: When testing LiveComponent events, use element selectors to click the actual DOM element rather than sending events directly.

### [2026-02-01] NavPanel shows letter indices, not tag names by default

**Context**: The NavPanel component organizes tags by first letter. By default, only letter indices (A, B, C...) are shown. Actual tag names only appear after clicking an index to expand it.

**Test implication**: To verify tags exist, either:
1. Check for the letter index (e.g., `assert html =~ "T"` for tags starting with T)
2. Click the index first, then check for tag names:
```elixir
view |> element("#index-selectors button", "T") |> render_click()
html = render(view)
assert html =~ "tag_name"
```

### [2026-01-24] Manual debugging with `mix run -e` creates stale data

**Problem**: When debugging code using `mix run -e "..."` (without `MIX_ENV=test`), database records are created in the dev database. If the same database is shared with tests, or if `MIX_ENV=test mix run -e` is used, this creates persistent records that pollute test runs since they bypass Ecto sandbox isolation.

**Symptoms**: Tests fail with unexpected data (extra photos, folders, or tags appearing), unique constraint violations on hardcoded names like "test_folder".

**Solution**: After manual debugging that creates database records, reset the test database:
```bash
docker compose -f docker-compose-dev.yml run --rm dev_app bash -c 'MIX_ENV=test mix ecto.reset'
```

**Prevention**: When writing manual test scripts, use unique names (e.g., `"test_#{System.unique_integer([:positive])}"`) instead of hardcoded names like "test_folder".
