# Architectural Decision Records

Document important technical decisions and their rationale.

## Format

```markdown
### [YYYY-MM-DD] Decision Title

**Status**: Proposed | Accepted | Deprecated | Superseded
**Context**: What situation prompted this decision
**Decision**: What was decided
**Consequences**: Positive and negative outcomes
**Alternatives Considered**: Other options that were evaluated
```

---

## Decisions

### [2026-02-12] Cross-listing as database-only references (no file duplication)

**Status**: Accepted
**Context**: Need to show a single photo in multiple folders without wasting disk space.
**Decision**: Cross-listed photos are full `Photo` records with `original_photo_id` pointing to the original. They share the original's files and generate URLs using the original's folder path. File storage remains unchanged.
**Consequences**:
- Positive: No disk duplication; simple cleanup (delete DB row only)
- Negative: URL generation requires preloading `original_photo.folder`; deleting an original cascades to all cross-listings
**Alternatives Considered**:
- Symlinks on disk: OS-dependent, harder to manage, doesn't work with cloud storage
- Separate join table (photo_folders): Would require reworking all photo queries; Photo schema stays simpler as a single record per entry

---

### [2026-02-12] Independent metadata per cross-listing (no sync)

**Status**: Accepted
**Context**: Cross-listed photos could either sync metadata with the original or be independent after creation.
**Decision**: Each cross-listing is fully independent after creation. Tags, description, visibility, etc. are copied at creation time but never synchronized afterward.
**Consequences**:
- Positive: Simple implementation; users can customize per-folder appearance; no sync complexity or race conditions
- Negative: Metadata drift between original and cross-listings; no way to bulk-update all copies at once
**Alternatives Considered**:
- Automatic sync: Complex to implement, unclear which direction syncs, surprising behavior when editing
- Optional sync toggle: Added complexity for marginal benefit

---

### [2026-02-12] Prevent cross-listing chains (only originals can be cross-listed)

**Status**: Accepted
**Context**: A cross-listing could itself be cross-listed, creating chains or trees of references.
**Decision**: Only original photos (`original_photo_id IS NULL`) can be cross-listed. Attempting to cross-list a cross-listing returns an error.
**Consequences**:
- Positive: Simple mental model; file URL resolution always one hop; clean cascade on delete
- Negative: To cross-list a photo that's already a cross-listing, user must find the original first
**Alternatives Considered**:
- Allow chains (resolve to root): More flexible but adds complexity to every query and URL generation

---

### [2026-02-12] Allow duplicate names across folders for cross-listings

**Status**: Accepted
**Context**: Cross-listed photos keep the original's name, which could conflict with existing photos in the target folder.
**Decision**: Allow duplicate names since the unique constraint is already scoped to `[name, folder_id]`. Same name in different folders is fine.
**Consequences**:
- Positive: No surprising renames; cross-listing name matches original by default
- Negative: None significant — constraint already handles this
**Alternatives Considered**:
- Auto-rename (e.g., "photo (cross-listed).jpg"): Confusing, loses original name context

---

### [2026-02-12] Block moving original to folder where it's already cross-listed

**Status**: Accepted
**Context**: Moving an original photo to a folder where a cross-listing of it already exists would create a conflict.
**Decision**: `update_photo/2` returns `{:error, :cross_listing_exists_in_target_folder}` if the target folder already has a cross-listing. User must remove the cross-listing first.
**Consequences**:
- Positive: Prevents confusing duplicate state; explicit user action required
- Negative: Extra step for users wanting to "promote" a cross-listing to the real location
**Alternatives Considered**:
- Auto-remove the cross-listing on move: Could surprise users who set up folder-specific metadata on the cross-listing
- Merge/swap: High complexity for a rare operation

---

### [2026-02-12] Cascade delete cross-listings when original is deleted

**Status**: Accepted
**Context**: When an original photo is deleted, its cross-listings become orphaned since they have no files of their own.
**Decision**: Use `on_delete: :delete_all` in the migration. Deleting an original removes all its cross-listings. The delete confirmation UI shows the count of affected cross-listings.
**Consequences**:
- Positive: No orphaned records; clean database state; user is warned before deletion
- Negative: Deleting one photo can silently remove entries from other folders
**Alternatives Considered**:
- Promote one cross-listing to original: Complex file ownership transfer; which one gets promoted?
- Soft delete / archive: Adds complexity without clear user benefit

---

### [2026-02-12] Block moving cross-listing to same folder as original

**Status**: Accepted
**Context**: A cross-listing exists to allow a photo to appear in multiple folders. If a cross-listing is moved to the same folder as its original, both records would exist in the same folder, defeating the purpose and creating UI confusion.
**Decision**: `update_photo/2` returns `{:error, :cross_listing_in_same_folder_as_original}` if attempting to move a cross-listing to its original's folder. The LiveView displays a user-friendly error message.
**Consequences**:
- Positive: Prevents invalid state where original and cross-listing coexist in same folder; maintains clear separation
- Negative: Users must delete the cross-listing first if they want both in the same folder (rare scenario)
**Alternatives Considered**:
- Auto-delete the cross-listing on move: Could surprise users; explicit action is safer
- Allow the invalid state: Would confuse UI and violate the cross-listing concept
