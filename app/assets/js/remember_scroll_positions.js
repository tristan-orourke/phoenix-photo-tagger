const fix_scroll = (element_id) => {
  const element = document.getElementById(element_id);
  if (element) {
    element.scrollTop = localStorage.getItem(`${element_id}-scroll-position`);
    element.addEventListener("scrollend", function(event) {
      localStorage.setItem(`${element_id}-scroll-position`, event.target.scrollTop);
    });
  }
}

fix_scroll("gallery-section");
fix_scroll("folder-section");
fix_scroll("photo-section");