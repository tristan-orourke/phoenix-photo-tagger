# AGENTS.md

Instructions for AI coding assistants (Cursor, GitHub Copilot, Codeium, etc.) working with this codebase.

## Project Overview

Photo Tagger is a Phoenix/Elixir web application for organizing and browsing photos with tag-based filtering. Uses LiveView, PostgreSQL, and Waffle for image uploads.

## Development Environment

All mix commands must run inside the Docker container:

```bash
docker-compose -f docker-compose-dev.yml run --user $(id -u):$(id -g) app bash
```

Phoenix app lives in `app/` directory. Dev server runs on port 4001.

## Project Memory System

This project maintains a structured memory system in `docs/project_notes/`. **Always check these files before making changes.**

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

## Key Architecture

- **Main context**: `lib/photo_tagger/gallery.ex` - all photo/tag/folder operations
- **LiveViews**: `lib/photo_tagger_web/live/gallery_live/`
- **Routes**: `/` (public), `/admin` (CRUD + management)
- **Schemas**: Photo, Tag, Folder, PhotoTag

## Coding Patterns

- Use `:include_private` option for public/private filtering
- Use `Ecto.Multi` for operations combining DB and filesystem changes
- Tag filtering uses `%{include: [...], exclude: [...]}` maps
