# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photo Tagger is a Phoenix/Elixir web application for organizing and browsing photos with tag-based filtering. It uses LiveView for interactive UI, PostgreSQL for storage, and Waffle for image uploads.

## Development Commands

**Important:** Due to file permissions, all mix commands must be run inside the development Docker container:

```bash
# Start container and open bash shell
docker-compose -f docker-compose-dev.yml run --user $(id -u):$(id -g) app bash

# Or run a single command
docker-compose -f docker-compose-dev.yml run --user $(id -u):$(id -g) app <command>
```

All commands below run from the `app/` directory inside the container:

```bash
# Setup and run
mix setup              # Install deps, create DB, run migrations, build assets
mix phx.server         # Start dev server at localhost:4001 (via docker-compose-dev)
iex -S mix phx.server  # Start with interactive Elixir shell

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
- `main.ex` - Primary gallery LiveView (~1400 lines), handles multiple route actions (`:public`, `:index`, `:folder`, `:photos`)
- `drift.ex` - Photo carousel/drift navigation mode
- Component modules: `nav_panel.ex`, `gallery_panel.ex`, `gallery_photo.ex`, `gallery_tag_link.ex`

### Routes

Two main scopes in `router.ex`:
- `/` - Public browsing (folders, photos, drift view)
- `/admin` - Full CRUD operations, folder/tag management, LiveDashboard

### Image Uploads

Waffle uploader at `lib/photo_tagger/uploaders/image_uploader.ex` handles:
- Multiple image versions (original, web, thumbnail)
- Storage path based on folder name
- File naming with photo metadata
