# Folder Visibility Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DATABASE LAYER                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Old Schema:                                                              │
│  ┌────────────────────────┐                                              │
│  │ folders                │                                              │
│  ├────────────────────────┤                                              │
│  │ id: integer            │                                              │
│  │ name: string           │                                              │
│  │ is_public: boolean  ❌ │  (REMOVED)                                   │
│  │ ...                    │                                              │
│  └────────────────────────┘                                              │
│                                                                           │
│  New Schema:                                                              │
│  ┌────────────────────────┐                                              │
│  │ folders                │                                              │
│  ├────────────────────────┤                                              │
│  │ id: integer            │                                              │
│  │ name: string           │                                              │
│  │ visibility_type: enum ✅│  (NEW)                                      │
│  │   • private            │                                              │
│  │   • public             │                                              │
│  │   • unlisted           │                                              │
│  │ ...                    │                                              │
│  └────────────────────────┘                                              │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        CONTEXT LAYER (Gallery)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Folder Filtering:                                                        │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │ list_folders(include_private: false) [DEFAULT]                 │     │
│  │ ├─> WHERE visibility_type = 'public'                           │     │
│  │ └─> Returns: [PUBLIC folders only]                             │     │
│  │                                                                  │     │
│  │ list_folders(include_private: true) [ADMIN]                    │     │
│  │ ├─> No WHERE clause on visibility                              │     │
│  │ └─> Returns: [PRIVATE, PUBLIC, UNLISTED folders]               │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                           │
│  Photo Filtering:                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │ list_photos(include_private: false) [DEFAULT]                  │     │
│  │ ├─> WHERE folder.visibility_type IN ('public', 'unlisted')     │     │
│  │ └─> Returns: [Photos from PUBLIC and UNLISTED folders]         │     │
│  │                                                                  │     │
│  │ list_photos_by_folder(name) [DIRECT ACCESS]                    │     │
│  │ ├─> WHERE folder.name = name                                   │     │
│  │ └─> Returns: [Photos from specified folder, works for UNLISTED]│     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                          UI LAYER (Phoenix)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Admin View:                                                              │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │ /admin/edit-folders                                            │     │
│  │                                                                  │     │
│  │ ┌──────────────────────────────────────────────────────┐       │     │
│  │ │ Folder: vacation_2024                                │       │     │
│  │ │ Name: [vacation_2024                    ]            │       │     │
│  │ │ Visibility:                                          │       │     │
│  │ │   ( ) Private   (•) Public   ( ) Unlisted           │       │     │
│  │ │ [Update folder]                                      │       │     │
│  │ └──────────────────────────────────────────────────────┘       │     │
│  │                                                                  │     │
│  │ Folder Dropdown (shows all folders):                            │     │
│  │ ┌────────────────────────────┐                                 │     │
│  │ │ All Folders              ▼ │                                 │     │
│  │ │ private_photos             │                                 │     │
│  │ │ vacation_2024              │                                 │     │
│  │ │ hidden_project             │                                 │     │
│  │ └────────────────────────────┘                                 │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                           │
│  Public View:                                                             │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │ /folders (folder listing)                                      │     │
│  │                                                                  │     │
│  │ Shows only:                                                      │     │
│  │   • vacation_2024 (public)                                      │     │
│  │                                                                  │     │
│  │ Does NOT show:                                                   │     │
│  │   ✗ private_photos (private)                                    │     │
│  │   ✗ hidden_project (unlisted)                                   │     │
│  │                                                                  │     │
│  │ Folder Dropdown (shows only public):                            │     │
│  │ ┌────────────────────────────┐                                 │     │
│  │ │ All Folders              ▼ │                                 │     │
│  │ │ vacation_2024              │                                 │     │
│  │ └────────────────────────────┘                                 │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                           │
│  Public Direct Access:                                                    │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │ /folders/hidden_project (direct URL to unlisted folder)        │     │
│  │                                                                  │     │
│  │ ✅ Works! Shows photos from "hidden_project"                   │     │
│  │                                                                  │     │
│  │ /folders/private_photos (direct URL to private folder)         │     │
│  │                                                                  │     │
│  │ ❌ Fails! Returns empty or error                               │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      ACCESS CONTROL MATRIX                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────┬─────────────┬─────────────┬──────────────────────┐   │
│  │ Folder Type  │ In Dropdown │ Direct URL  │ Photos in Gallery    │   │
│  │              │ (Non-Admin) │ (Non-Admin) │ (Non-Admin)          │   │
│  ├──────────────┼─────────────┼─────────────┼──────────────────────┤   │
│  │ PRIVATE      │     ❌      │     ❌      │         ❌           │   │
│  │              │             │             │                      │   │
│  │ PUBLIC       │     ✅      │     ✅      │         ✅           │   │
│  │              │             │             │                      │   │
│  │ UNLISTED     │     ❌      │     ✅      │         ✅           │   │
│  └──────────────┴─────────────┴─────────────┴──────────────────────┘   │
│                                                                           │
│  Admin users have ✅ for all scenarios.                                 │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        MIGRATION PATH                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  BEFORE:                            AFTER:                               │
│  ┌──────────────────────┐           ┌──────────────────────┐            │
│  │ Folder A             │           │ Folder A             │            │
│  │ is_public: true  ──────────────> │ visibility: public   │            │
│  └──────────────────────┘           └──────────────────────┘            │
│                                                                           │
│  ┌──────────────────────┐           ┌──────────────────────┐            │
│  │ Folder B             │           │ Folder B             │            │
│  │ is_public: false ──────────────> │ visibility: private  │            │
│  └──────────────────────┘           └──────────────────────┘            │
│                                                                           │
│  (No UNLISTED folders exist pre-migration)                               │
│                                                                           │
│  ROLLBACK (if needed):                                                   │
│  ┌──────────────────────┐           ┌──────────────────────┐            │
│  │ Folder X             │           │ Folder X             │            │
│  │ visibility: unlisted ──────────> │ is_public: true ⚠️  │            │
│  └──────────────────────┘           └──────────────────────┘            │
│                                                                           │
│  Note: UNLISTED becomes PUBLIC on rollback (acceptable data loss)        │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                          USE CASES                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  1. PUBLIC FOLDER: "Family Vacation 2024"                                │
│     ✅ Everyone can see it in the folder list                           │
│     ✅ Everyone can browse the photos                                   │
│     → Use for: General public content                                    │
│                                                                           │
│  2. PRIVATE FOLDER: "Private Documents"                                  │
│     ❌ Hidden from non-admin users                                      │
│     ❌ Inaccessible to non-admin users                                  │
│     → Use for: Admin-only content                                        │
│                                                                           │
│  3. UNLISTED FOLDER: "Wedding Preview"                                   │
│     ❌ Hidden from folder dropdown                                      │
│     ✅ Accessible via direct link                                       │
│     ✅ Photos appear when browsing all photos                           │
│     → Use for: Share-by-link content                                     │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Implementation Details

### Database
- PostgreSQL ENUM ensures type safety at database level
- Migration preserves existing data
- Idempotent and reversible

### Code
- Ecto.Enum provides automatic conversion between strings/atoms
- Gallery context functions use `:include_private` flag pattern
- LiveView components already compatible (no changes needed)

### Security
- Private folders remain completely inaccessible to non-admins
- Unlisted folders provide controlled "hidden but accessible" feature
- Photo-level privacy respected independently

### Testing
- 30+ existing tests updated
- 8+ new tests specifically for UNLISTED behavior
- Manual test scenarios documented
