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
        // Don't do anything if nothing actually moved
        if (evt.oldIndex === evt.newIndex) {
          return;
        }
        
        // Get the photo ID from the dragged element
        const photoId = evt.item.dataset.galleryPhotoId;
        
        // Determine target: the photo whose position we're taking
        // After SortableJS moves the DOM:
        // - If we moved down/right, the target photo is now our previous sibling
        // - If we moved up/left, the target photo is now our next sibling
        let targetPhotoId;
        
        if (evt.oldIndex < evt.newIndex) {
          // Moved down/right: we're taking the position of our previous sibling
          const prevItem = evt.item.previousElementSibling;
          if (prevItem) {
            targetPhotoId = prevItem.dataset.galleryPhotoId;
          } else {
            targetPhotoId = "first";
          }
        } else {
          // Moved up/left: we're taking the position of our next sibling
          const nextItem = evt.item.nextElementSibling;
          if (nextItem) {
            targetPhotoId = nextItem.dataset.galleryPhotoId;
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
