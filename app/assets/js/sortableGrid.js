import Sortable from "sortablejs"

/** @type {import("phoenix_live_view").ViewHookInterface} */
const SortableGrid = {
	mounted() {
		const enabled = this.el.dataset.sortableEnabled === "true"
		console.log("[SortableGrid] mounted, enabled:", enabled, "element:", this.el.id)
		this.sortable = Sortable.create(this.el, {
			animation: 150,
			delay: 150,
			delayOnTouchOnly: false,
			ghostClass: "sortable-ghost",
			chosenClass: "sortable-chosen",
			dragClass: "sortable-drag",
			draggable: "[data-gallery-photo-id]",
			filter: "[data-group-collapsed]",
			preventOnFilter: true,
			disabled: !enabled,
			onStart: (evt) => {
				console.log("[SortableGrid] drag started", evt.item.dataset.galleryPhotoId)
			},
			onEnd: (evt) => {
				if (evt.oldIndex === evt.newIndex) return

				const draggedId = evt.item.dataset.galleryPhotoId
				const targetItem = this.el.children[evt.newIndex]
				if (!targetItem) return

				const targetId = targetItem.dataset.galleryPhotoId
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
