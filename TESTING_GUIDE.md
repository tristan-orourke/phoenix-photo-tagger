# Manual Testing Guide

## Prerequisites
- Phoenix development server running
- Admin access to the application
- A folder with at least 5 photos

## Step-by-Step Testing Instructions

### 1. Access Admin Gallery
```
URL: http://localhost:4001/admin
```
1. Navigate to the admin section
2. Select a folder that contains multiple photos

### 2. Enable Manual Sort Mode
1. Locate the sort dropdown (usually near top of gallery)
2. Click and select "Manual" from the options
3. Photos should now be arranged by manual_order

### 3. Test Basic Drag-and-Drop

#### Test A: Move Photo Down (Later in List)
**Before:**
```
[Photo1] [Photo2] [Photo3] [Photo4] [Photo5]
   ^                            
   └─ Drag this to Photo4
```

**Action:** Click and drag Photo1 to Photo4's position

**Expected Result:**
```
[Photo2] [Photo3] [Photo4] [Photo1] [Photo5]
```

**Verify:**
- Photo1 now has manual_order of Photo4 (was 4, Photo1 takes it)
- Photo2 shifted to position 1
- Photo3 shifted to position 2
- Photo4 shifted to position 3
- Photo5 remains at position 5

#### Test B: Move Photo Up (Earlier in List)
**Before:**
```
[Photo1] [Photo2] [Photo3] [Photo4] [Photo5]
                                ^
                    Drag this to Photo2 ─┘
```

**Action:** Click and drag Photo5 to Photo2's position

**Expected Result:**
```
[Photo1] [Photo5] [Photo2] [Photo3] [Photo4]
```

**Verify:**
- Photo5 now has manual_order of Photo2 (was 2, Photo5 takes it)
- Photo2 shifted to position 3
- Photo3 shifted to position 4
- Photo4 shifted to position 5

### 4. Test Visual Feedback

During each drag operation, verify:

✅ **Hover State**
- Cursor changes to "grab hand" (open hand icon)
- Only when hovering over photos
- Only in admin + manual sort mode

✅ **Drag Start**
- Cursor changes to "grabbing hand" (closed fist icon)
- Photo slightly rotates (2 degrees)
- Photo opacity reduces slightly

✅ **During Drag**
- Ghost element appears (semi-transparent blue preview)
- Ghost shows where photo will land
- Original photo follows mouse

✅ **Drop**
- Photo instantly moves to new position
- Other photos shift smoothly
- Ghost disappears

### 5. Test Edge Cases

#### Test C: Drag to First Position
**Before:**
```
[Photo1] [Photo2] [Photo3] [Photo4] [Photo5]
                      ^
           Drag to start ─┘
```

**Action:** Drag Photo3 all the way to the beginning (before Photo1)

**Expected Result:**
```
[Photo3] [Photo1] [Photo2] [Photo4] [Photo5]
```

#### Test D: Drag to Last Position
**Before:**
```
[Photo1] [Photo2] [Photo3] [Photo4] [Photo5]
           ^
           └─ Drag to end
```

**Action:** Drag Photo2 all the way to the end (after Photo5)

**Expected Result:**
```
[Photo1] [Photo3] [Photo4] [Photo5] [Photo2]
```

#### Test E: Drag and Drop in Same Position
**Action:** Click Photo3, drag slightly, then drop back on Photo3

**Expected Result:**
- No database update (optimization)
- Photo stays in same position
- No flash messages

#### Test F: No Movement
**Action:** Click Photo3 but don't drag (just click and release)

**Expected Result:**
- No drag operation triggers
- Photo stays selected (if multiselect is on)
- No reordering occurs

### 6. Test Conditional Activation

#### Test G: Date Sort Mode
**Setup:** Switch sort mode to "Date"

**Action:** Try to drag a photo

**Expected Result:**
- ❌ Cursor does NOT change to grab hand
- ❌ Photo cannot be dragged
- Photos remain in date order

#### Test H: Public Gallery View
**Setup:** Navigate to public gallery (non-admin)

**Action:** Try to drag a photo

**Expected Result:**
- ❌ Cursor does NOT change to grab hand
- ❌ Photo cannot be dragged
- Public view remains read-only

### 7. Test Persistence

#### Test I: Refresh Page
**Action:**
1. Drag photos to new positions
2. Note the new order
3. Refresh the page (F5 or Ctrl+R)

**Expected Result:**
- Photos remain in new order after refresh
- manual_order values persisted to database

#### Test J: Navigate Away and Back
**Action:**
1. Reorder photos
2. Navigate to a different folder
3. Navigate back to original folder

**Expected Result:**
- Photos still in reordered positions
- Order preserved across navigation

### 8. Test with Photo Groups

If using photo grouping feature:

#### Test K: Drag Within Group
**Setup:** Have photos with group assignments

**Action:** Drag a grouped photo to new position

**Expected Result:**
- Photo moves as expected
- Group styling maintained
- Other group members unaffected (if collapsed)

### 9. Test Performance

#### Test L: Large Gallery
**Setup:** Gallery with 50+ photos

**Action:** Drag photos in various positions

**Expected Result:**
- Drag remains smooth and responsive
- No lag or stuttering
- Database updates complete quickly

### 10. Test Error Handling

#### Test M: Network Failure Simulation
**Setup:** Use browser dev tools to throttle/block network

**Action:** Drag a photo during network issue

**Expected Result:**
- Error flash message appears
- Photo reverts to original position
- No data corruption

## Verification Checklist

After testing, verify these conditions:

- [ ] Drag-and-drop only works in admin + manual sort mode
- [ ] Visual feedback appears during all drag operations
- [ ] Photos reorder correctly in all scenarios
- [ ] Database persists changes across page refreshes
- [ ] No JavaScript errors in browser console
- [ ] No Elixir errors in server logs
- [ ] Performance remains smooth with many photos
- [ ] Public view remains unaffected
- [ ] Date sort mode disables drag-and-drop

## Screenshots to Capture

For documentation, capture these screenshots:

1. **Before State**: Initial photo order
2. **Hover**: Cursor showing grab hand
3. **During Drag**: Ghost element visible
4. **After Drop**: New photo order
5. **Date Sort**: Showing drag disabled
6. **Public View**: Showing drag disabled

## Troubleshooting

### Issue: Cursor doesn't change
**Check:**
- Are you in admin mode?
- Is sort set to "Manual"?
- Check browser console for JavaScript errors

### Issue: Photo doesn't move
**Check:**
- Did photo actually change position?
- Check network tab for reorder_photo event
- Check server logs for errors

### Issue: Order doesn't persist
**Check:**
- Database connection healthy?
- Check Ecto.Multi transaction logs
- Verify manual_order column exists

### Issue: Photos jump back
**Check:**
- Network errors during drag?
- Server-side validation failures?
- Check flash messages for errors

## Success Criteria

✅ All test cases pass  
✅ No JavaScript console errors  
✅ No Elixir server errors  
✅ Changes persist across refreshes  
✅ Visual feedback works as expected  
✅ Performance is acceptable  

## Reporting Issues

If you find any issues during testing:

1. Note exact steps to reproduce
2. Capture screenshot if visual issue
3. Include browser console errors
4. Include server log errors
5. Note browser/OS information
6. Document expected vs actual behavior

---

**Happy Testing! 🎉**
