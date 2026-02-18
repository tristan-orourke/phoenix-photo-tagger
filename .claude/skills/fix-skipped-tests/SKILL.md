---
description: Find and fix all skipped (@tag :skip) tests in the project
trigger: fix skipped tests, unskip tests, fix test skips
---

# Fix Skipped Tests

## Preparation

1. Check `docs/project_notes/bugs.md` for past bugs related to test failures
2. Review the "Testing" and "LiveView Test Patterns" sections in `.claude/CLAUDE.md` — these document the most common causes of test failures in this project

## Execution

Run all commands inside the dev container:
```bash
docker compose -f docker-compose-dev.yml run dev_app bash
```

### Find all skipped tests
```bash
grep -rn "@tag :skip" app/test/
```

### Fix tests in batches by file, starting with the smallest files first

For each file with skipped tests:
1. Identify all `@tag :skip` annotations and group by `describe` block
2. For each group:
   a. Remove the `@tag :skip` tags for that group
   b. Run just those tests: `mix test test/path/to/file.exs:LINE`
   c. If tests fail, diagnose and fix the **test code**. Avoid changing production code.
   d. If a test cannot be fixed without production changes, re-add the skip with a reason:
      `@tag skip: "Requires production change: <brief explanation>"`
   e. Run the full file (`mix test test/path/to/file.exs`) to check for regressions before moving on

Use subagents to run tests and fix individual test groups in parallel when they are independent.

### Common failure patterns in this project

- Event params must use **string keys and string values**: `%{"photo_id" => "123"}`
- Cannot access `view.assigns` — assert via rendered HTML with `has_element?/3`
- `update_photo` event requires nested params: `%{"photo_id" => id, "photo" => %{...}}`
- Admin routes are `/admin`, `/admin/photos/{id}` — no `/admin/gallery`
- `Gallery.add_tag_to_photo(photo, tag_name)` takes a string, not a tag struct
- `form_group_from_selected` takes no parameters
- Event handler parameter names: `"tag"` (not "tag_id"), `"photo_group"` (not "group_name"), `"folder"` (not "folder_name")

## Verification

After all files are processed:
1. Run the full test suite: `mix test`
2. Confirm no regressions — all previously-passing tests still pass
3. Report: how many tests were fixed, how many remain skipped (with reasons)

## Post-completion

- Log any bugs discovered in `docs/project_notes/bugs.md`
- Update `docs/project_notes/issues.md` with work completed
