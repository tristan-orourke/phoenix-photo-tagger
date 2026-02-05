# Testing Shift-Click Multiselect Feature

This document describes how to manually test the shift-click multiselect functionality implemented for photo selection.

## Prerequisites

1. Start the development server:
   ```bash
   docker compose -f docker-compose-dev.yml up dev_app
   ```

2. Navigate to the admin interface at `http://localhost:4001/admin`

3. Ensure you have multiple photos uploaded in a folder

## Test Scenarios

### Basic Shift-Click Selection

1. **Single photo selection (baseline)**
   - Click on any photo
   - Verify: Only that photo is selected (blue outline)

2. **Shift-click range selection**
   - Click on photo #1
   - Hold Shift and click on photo #5
   - Expected: Photos #1, #2, #3, #4, and #5 are all selected

3. **Reverse range selection**
   - Click on photo #5
   - Hold Shift and click on photo #1
   - Expected: Photos #1, #2, #3, #4, and #5 are all selected (same as above)

4. **Extending selection with shift-click**
   - Click photo #1
   - Hold Shift and click photo #3 (selects 1-3)
   - Hold Shift and click photo #6 (should select 3-6, adding to existing)
   - Expected: Photos #1, #2, #3, #4, #5, and #6 are selected

### Multi-select Mode

1. **Enable multiselect mode**
   - Click the "Multi-select" toggle button
   - Click photo #1
   - Click photo #3 (without shift)
   - Expected: Both #1 and #3 are selected

2. **Shift-click works with or without multiselect mode**
   - With multiselect enabled, click photo #1
   - Hold Shift and click photo #4
   - Expected: Photos #1, #2, #3, and #4 are selected

3. **Shift-click works without multiselect mode**
   - Turn off multiselect mode
   - Click photo #1 (single selection)
   - Hold Shift and click photo #5
   - Expected: Photos #1, #2, #3, #4, and #5 are selected (range selection works without multiselect mode)

### Collapsed Groups Edge Case

If your photos have groups set up:

1. **Enable group collapse**
   - Click the "Collapse Groups" toggle
   - Verify: Grouped photos show as collapsed (stacked appearance)

2. **Shift-click with collapsed group in range**
   - Click on a photo before a collapsed group
   - Hold Shift and click on a photo after the collapsed group
   - Expected: ALL photos in the collapsed group are selected, even though only one representative is visible

3. **Verify hidden photos are selected**
   - Open the photo panel on the right
   - Verify: All photos from the collapsed group appear in the selection list

### Pagination Edge Cases

If you have pagination enabled:

1. **Shift-click across pages** (should gracefully handle)
   - Click photo on page 1
   - Navigate to page 2
   - Hold Shift and click a photo
   - Expected: Since the previous photo is not visible, only the clicked photo is selected (falls back to single select)

### Compatibility Tests

1. **Regular ctrl-click still works**
   - Click photo #1
   - Hold Ctrl and click photo #3
   - Hold Ctrl and click photo #5
   - Expected: Photos #1, #3, and #5 are selected (non-contiguous)

2. **Toggle deselection**
   - Select photos #1-5 with shift-click
   - Hold Ctrl and click photo #3
   - Expected: Photo #3 is deselected, #1, #2, #4, #5 remain selected

## Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| Click | Single photo selected |
| Shift+Click | Range from last selected to clicked photo selected |
| Ctrl+Click | Toggle individual photo in/out of selection |
| Multiselect + Click | Toggle individual photo |
| Multiselect + Shift+Click | Range from last selected to clicked photo |

Note: Shift+Click works independently - it does not require Ctrl to be pressed or multiselect mode to be enabled.

## Common Issues to Watch For

1. **Trailing selection issues**: Verify that the "last selected" photo updates correctly after each selection operation
2. **Group expansion**: Ensure collapsed groups are fully expanded when in range
3. **Visual feedback**: Blue outline should clearly show all selected photos
4. **Performance**: Shift-click should feel snappy even with 50+ photos visible

## Reporting Bugs

If you find any issues during testing, please report:
- The exact steps to reproduce
- Expected behavior
- Actual behavior
- Browser and version
- Any console errors
