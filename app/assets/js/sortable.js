import Sortable from "../node_modules/sortablejs/modular/sortable.complete.esm.js";

const SortableHook = {
    mounted() {
        this.initSortable();
    },
    updated() {
        // If the element is updated, we might need to re-init or check status?
        // Sortable usually handles DOM updates if the list container persists.
        // But if LiveView patches the container, we might lose Sortable instance.
        // Storing instance on element.
    },
    destroyed() {
        if (this.sortable) {
            this.sortable.destroy();
        }
    },
    initSortable() {
        let hook = this;
        let list = this.el;

        // Only enable if data-enabled is true
        if (list.dataset.enabled !== "true") return;

        this.sortable = new Sortable(list, {
            animation: 150,

            onEnd: function (evt) {
                if (evt.oldIndex === evt.newIndex) return;

                const itemId = evt.item.getAttribute("data-id");
                if (!itemId) return;

                hook.pushEvent("reorder", {
                    id: itemId,
                    new_index: evt.newIndex
                });
            }
        });
    }
};

export default SortableHook;
