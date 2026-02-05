// Hook for SortableJS drag-and-drop functionality
// Handles photo reordering in the admin gallery view

import Sortable from "https://cdn.jsdelivr.net/npm/sortablejs@1.15.3/+esm";

const SortableHook = {
  mounted() {
    const hook = this;
    
    // Create sortable instance on the gallery grid
    this.sortable = Sortable.create(this.el, {
      animation: 150,
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      dragClass: "sortable-drag",
      
      // Only allow dragging if we're in admin mode
      filter: function(evt, target) {
        // Check if we're in admin mode (data attribute on parent)
        return !hook.el.dataset.sortableEnabled;
      },
      
      // Handle the drop event
      onEnd: function(evt) {
        // Get the photo ID from the dragged element
        const photoId = evt.item.dataset.galleryPhotoId;
        
        // Get the photo ID of the target position (where it was dropped)
        let targetPhotoId = null;
        
        if (evt.newIndex < evt.oldIndex) {
          // Dropped earlier in list - get the ID of the photo now after this one
          const nextItem = evt.item.nextElementSibling;
          targetPhotoId = nextItem ? nextItem.dataset.galleryPhotoId : null;
        } else {
          // Dropped later in list - get the ID of the photo now before this one
          const prevItem = evt.item.previousElementSibling;
          targetPhotoId = prevItem ? prevItem.dataset.galleryPhotoId : null;
        }
        
        // If no target (dropped at beginning or end), use special values
        if (!targetPhotoId) {
          if (evt.newIndex === 0) {
            targetPhotoId = "first";
          } else {
            targetPhotoId = "last";
          }
        }
        
        // Send the reorder event to LiveView
        hook.pushEvent("reorder_photo", {
          photo_id: photoId,
          target_photo_id: targetPhotoId,
          new_index: evt.newIndex,
          old_index: evt.oldIndex
        });
      }
    });
  },
  
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  }
};

export default SortableHook;
