# Folder Visibility Test Scenarios

This document outlines the expected behavior for the three folder visibility types: **Private**, **Public**, and **Unlisted**.

## Visibility Types

### 1. Private Folders
- **Not visible** in folder listings/dropdowns for non-admins
- **Not accessible** directly by non-admins (even with a direct link)
- **Visible and accessible** to admins in all contexts
- Photos in private folders are **not shown** to non-admins

### 2. Public Folders
- **Visible** in folder listings/dropdowns for all users
- **Accessible** to all users via direct links
- Photos in public folders are **shown** to all users (if photos are also public)

### 3. Unlisted Folders (NEW)
- **Not visible** in folder listings/dropdowns for non-admins
- **Accessible** directly via URL by non-admins (they can view the folder if they have the link)
- **Visible and accessible** to admins in all contexts
- Photos in unlisted folders are **shown** to non-admins when:
  - Accessing the folder directly by URL/name
- Photos in unlisted folders are **NOT shown** to non-admins when:
  - Browsing all photos (unlisted folder photos do NOT appear in the general gallery)
  - Searching by tags (unless within the unlisted folder context)

## Test Cases

### Test Case 1: Admin Folder Listing
**Scenario:** Admin views `/admin/edit-folders`

**Expected Results:**
- All three folder types are shown
- Each folder has radio buttons: Private, Public, Unlisted
- Can change any folder's visibility type

### Test Case 2: Admin Folder Dropdown
**Scenario:** Admin views navigation panel with folder dropdown

**Expected Results:**
- All three folder types appear in the dropdown
- Can select any folder to filter photos

### Test Case 3: Non-Admin Folder Listing
**Scenario:** Non-admin views `/folders` (public folder listing)

**Expected Results:**
- Only PUBLIC folders are listed
- Private folders are NOT shown
- Unlisted folders are NOT shown

### Test Case 4: Non-Admin Folder Dropdown
**Scenario:** Non-admin views navigation panel with folder dropdown

**Expected Results:**
- Only PUBLIC folders appear in dropdown
- Private folders are NOT in dropdown
- Unlisted folders are NOT in dropdown

### Test Case 5: Unlisted Folder Direct Access (Non-Admin)
**Scenario:** Non-admin navigates to `/folders/{unlisted_folder_name}`

**Expected Results:**
- User CAN view the unlisted folder
- Photos in the unlisted folder are displayed
- User can browse photos normally

### Test Case 6: Private Folder Direct Access (Non-Admin)
**Scenario:** Non-admin navigates to `/folders/{private_folder_name}`

**Expected Results:**
- User gets empty results or error
- Photos are NOT displayed
- Access is denied

### Test Case 7: Photo Listings with Unlisted Folders (Non-Admin)
**Scenario:** Non-admin views all photos (no folder filter)

**Expected Results:**
- Photos from PUBLIC folders are shown
- Photos from UNLISTED folders are NOT shown
- Photos from PRIVATE folders are NOT shown

### Test Case 8: Migration from Old is_public Field
**Scenario:** Existing database has folders with `is_public` boolean

**Expected Results:**
- Migration converts `is_public: true` → `visibility_type: public`
- Migration converts `is_public: false` → `visibility_type: private`
- Rollback converts `visibility_type: unlisted` → `is_public: false` (private)
- No data loss occurs
- All folders remain functional

## Manual Testing Steps

### Setup Test Data
1. Create three folders via admin UI:
   - `test_public` with visibility: Public
   - `test_private` with visibility: Private
   - `test_unlisted` with visibility: Unlisted
2. Add at least one public photo to each folder

### Test as Admin
1. Visit `/admin/edit-folders` - verify all three folders shown with correct visibility type
2. Visit `/admin` - verify all three folders in navigation dropdown
3. Change each folder's visibility type and verify it saves correctly

### Test as Non-Admin
1. Visit `/folders` - verify only `test_public` is shown
2. Visit `/` and check folder dropdown - verify only `test_public` in dropdown
3. Visit `/folders/test_unlisted` directly - verify it loads and shows photos
4. Visit `/folders/test_private` directly - verify access denied or empty results
5. Browse all photos - verify photos from both public and unlisted folders appear

## Database Schema

The `folders` table now has:
```sql
visibility_type: ENUM('private', 'public', 'unlisted') NOT NULL DEFAULT 'private'
```

The old `is_public` boolean field has been removed.

## Gallery Context Functions

### Folder Filtering Logic
- `Gallery.list_folders()` - Returns only PUBLIC folders
- `Gallery.list_folders(include_private: true)` - Returns ALL folders (private, public, unlisted)

### Photo Filtering Logic  
- `Gallery.list_photos()` - Returns photos from PUBLIC folders only (excludes UNLISTED)
- `Gallery.list_photos_by_folder(name)` - Returns photos from specified folder (works for unlisted when accessed by name)
- Both respect photo-level `is_public` flag as well

## Notes

- The visibility types are implemented as a PostgreSQL ENUM for database-level validation
- Unlisted folders are useful for sharing specific galleries via direct link without exposing them in public listings
- Photos in unlisted folders are ONLY visible when accessing the folder directly, not in general photo browsing
- Photos have their own `is_public` flag which is respected independently
- Both folder AND photo must allow access for a photo to be visible to non-admins
