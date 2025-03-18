window.addEventListener("phx:scroll_to_top", (event) => {
    const el = document.querySelector(event.detail.selector);
    if(el) {
        el.scroll(0,0);
    }
});

window.addEventListener("phx:scroll_into_view", (event) => {
    const el = document.querySelector(event.detail.selector);
    if(el) {
        el.scrollIntoView();
    }
})