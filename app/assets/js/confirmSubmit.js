// Hook to confirm form submission before it goes to the server
// Prevents LiveView from bypassing onsubmit confirmation dialogs
const ConfirmSubmit = {
  mounted() {
    // Get the confirmation message from data-confirm attribute
    const confirmMessage = this.el.dataset.confirm || "Are you sure?";
    
    this.el.addEventListener("submit", (e) => {
      if (!confirm(confirmMessage)) {
        e.preventDefault(); // Prevents both native submit and phx-submit
        e.stopPropagation();
      }
    });
  }
};

export default ConfirmSubmit;
