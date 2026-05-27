import Sortable from "sortablejs"

/** @type {import("phoenix_live_view").ViewHookInterface} */
const SortableGrid = {
	mounted() {
		const enabled = this.el.dataset.sortableEnabled === "true"
		this.sortable = Sortable.create(this.el, {
			animation: 150,
			delay: 150,
			delayOnTouchOnly: true,
			ghostClass: "sortable-ghost",
			chosenClass: "sortable-chosen",
			dragClass: "sortable-drag",
			draggable: "[data-gallery-photo-id]",
			filter: "[data-group-collapsed]",
			preventOnFilter: true,
			disabled: !enabled,
			onEnd: (evt) => {
				if (evt.oldIndex === evt.newIndex) return

				const draggedId = evt.item.dataset.galleryPhotoId
				// After SortableJS moves the DOM, the dragged item is at newIndex.
				// The displaced neighbor is at oldIndex (if moved forward) or newIndex+1 (if moved backward).
				const neighborIndex = evt.oldIndex < evt.newIndex
					? evt.newIndex - 1
					: evt.newIndex + 1
				const neighborItem = this.el.children[neighborIndex]
				if (!neighborItem) return

				const targetId = neighborItem.dataset.galleryPhotoId
				if (!targetId) return

				this.pushEvent("reorder_photo", {
					dragged_photo_id: draggedId,
					target_photo_id: targetId,
				})
			},
		})
	},

	updated() {
		const enabled = this.el.dataset.sortableEnabled === "true"
		this.sortable.option("disabled", !enabled)
	},

	destroyed() {
		this.sortable.destroy()
	},
}

export default SortableGrid
