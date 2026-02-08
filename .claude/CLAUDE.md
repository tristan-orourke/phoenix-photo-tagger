# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photo Tagger is a Phoenix/Elixir web application for organizing and browsing photos with tag-based filtering. It uses LiveView for interactive UI, PostgreSQL for storage, and Waffle for image uploads.

## Development Commands

**Important:** Due to file permissions, all mix commands must be run inside the development Docker container:

```bash
# Start container and open bash shell
docker compose -f docker-compose-dev.yml run dev_app bash

# Or run a single command
docker compose -f docker-compose-dev.yml run dev_app <command>
```

All commands below run from the `app/` directory inside the container:

```bash
# Setup and run
mix compile             # Compile elixir code
mix setup               # Install deps, create DB, run migrations, build assets
mix phx.server          # Start dev server at localhost:4001 (via docker-compose-dev)
iex -S mix phx.server   # Start with interactive Elixir shell

# Database
mix ecto.migrate       # Run pending migrations
mix ecto.reset         # Drop, recreate, and migrate database

# Testing
mix test               # Run all tests
mix test test/path/to/test.exs           # Run specific test file
mix test test/path/to/test.exs:42        # Run specific test at line 42

# Assets
mix assets.build       # Build Tailwind CSS and esbuild assets
mix assets.deploy      # Minify assets for production
```
## Style Conventions

Avoid unused variables where possible. But if necessary, unused variables *must* be prefixed with `_`. 
`_unused_variable = 123;`

## UI Design

UI is designed to be clear and navigable at various screen sizes, particularly mobile, landscape mobile, and desktop. Tailwind CSS classes use md: and lg: to scale down spacing and some element sizes on smaller screens. Some elements are hidden entirely on smaller screens, such as some labels, to save space for more important UI.

## Architecture

### Directory Structure

The Phoenix app lives in `app/`. Key directories:
- `lib/photo_tagger/` - Business logic contexts
- `lib/photo_tagger_web/` - Web layer (routes, controllers, LiveViews)
- `priv/repo/migrations/` - Database migrations
- `assets/` - JS and Tailwind CSS

### Core Context: PhotoTagger.Gallery

`lib/photo_tagger/gallery.ex` is the main context handling all photo/tag/folder operations. Key patterns:

- **Public/private filtering**: Most query functions accept `options` with `:include_private` flag. Functions like `only_public_photos_unless_forced/2` filter out private content by default.
- **Tag filtering**: `list_photos_by_tags/2` supports `%{include: [...], exclude: [...]}` maps for AND-based include and exclude filtering.
- **File operations**: Photo/folder mutations use `Ecto.Multi` to coordinate database changes with filesystem operations (renaming, moving images).

### Schemas

- `Photo` - Has image attachment (Waffle), belongs to folder, many-to-many with tags
- `Tag` - Case-insensitive names (CITEXT in PostgreSQL)
- `Folder` - Contains photos, has `is_public` flag
- `PhotoTag` - Join table for photo-tag associations

### LiveView Structure

Main gallery interface in `lib/photo_tagger_web/live/gallery_live/`:
- `main.ex` - Primary gallery LiveView (~1500 lines), handles multiple route actions (`:public`, `:index`, `:folder`, `:photos`)
- `drift.ex` - Photo carousel/drift navigation mode
- Component modules: `nav_panel.ex`, `gallery_panel.ex`, `gallery_photo.ex`, `gallery_tag_link.ex`, `public_gallery.ex`, `util.ex`

### Routes

Two main scopes in `router.ex`:
- `/` - Public browsing (folders, photos, drift view)
- `/admin` - Full CRUD operations, folder/tag management, LiveDashboard

### Image Uploads

Waffle uploader at `lib/photo_tagger/uploaders/image_uploader.ex` handles:
- Multiple image versions (original, web, thumbnail)
- Storage path based on folder name
- File naming with photo metadata

## Project Memory System

This project maintains a structured memory system in `docs/project_notes/` to track bugs, decisions, key facts, and work history.

### Memory Files

| File | Purpose |
|------|---------|
| `docs/project_notes/bugs.md` | Bug log with root causes and solutions |
| `docs/project_notes/decisions.md` | Architectural Decision Records (ADRs) |
| `docs/project_notes/key_facts.md` | Essential project information and configuration |
| `docs/project_notes/issues.md` | Work log tracking completed and in-progress work |

### Memory-Aware Protocols

**Before making changes:**
1. Check `bugs.md` for related past issues that might inform your approach
2. Check `decisions.md` for relevant architectural decisions that should guide implementation
3. Review `key_facts.md` for project-specific constraints or patterns

**After completing work:**
1. Log any bugs discovered and fixed in `bugs.md`
2. Record significant architectural decisions in `decisions.md`
3. Update `key_facts.md` if new essential project information was learned
4. Add completed work to `issues.md`

### Memory Entry Guidelines

- Use date prefix `[YYYY-MM-DD]` for all entries
- Keep entries concise but complete
- Link to related GitHub issues/PRs when applicable
- Include file paths affected by changes
- Document both what was done and why

## Testing

Always run tests in a subagent to avoid polluting context, unless the details of how a test fails are important to solving it.

### LiveView Test Patterns

- Event parameters must use string keys and string values: `%{"photo_id" => "123", "ctrl_key_pressed" => "true"}`
- No access to `view.assigns` in tests - verify behavior through rendered HTML with `has_element?/3` and Floki parsing
- Use mocked fixtures from `PhotoTagger.GalleryFixtures` - no filesystem operations needed
- LiveComponent events bubble up to parent LiveView's `handle_event/3`

### Gallery API Signatures

- `Gallery.add_tag_to_photo(photo, tag_name)` - takes photo struct and tag name (string), not tag struct
- `Gallery.get_photo!/1` exists but `Gallery.get_photo/1` doesn't - use `catch_error(Gallery.get_photo!/1) == :error` for deletion tests
- Event handler parameter names: `"tag"` (not "tag_id"), `"photo_group"` (not "group_name"), `"folder"` (not "folder_name")
- `update_photo` event requires nested parameters: `%{"photo_id" => id, "photo" => %{"description" => "..."}}`
- `form_group_from_selected` takes no parameters - auto-generates timestamp-based group names or reuses existing group from selected photos

### Route Patterns

- Admin routes: `/admin`, `/admin/photos/{id}`, `/admin/folders/{name}` (no `/admin/gallery`)
- Drift routes require photo context: `/photos/{id}/drift` or `/folders/{folder}/photos/{id}/drift`

## Context Efficiency

To minimize context window usage in long sessions:
- Use Task tool with `subagent_type=Explore` for codebase searches - returns summaries instead of raw results
- Avoid re-reading files already in context - recall from memory instead
- Run specific tests (`mix test path:line`) rather than full test files when debugging
- Use `offset`/`limit` parameters when reading large files like `main.ex` (~1400 lines)
