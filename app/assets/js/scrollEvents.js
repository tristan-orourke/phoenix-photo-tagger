window.addEventListener("pxh:scroll_to_top", (event) => {
    const el = document.querySelector(event.detail.selector);
    if(el) {
        el.scroll(0,0);
        console.log("scrolling to top");
    }
});

window.addEventListener("photo_tagger:scroll_into_view", (event) => {
    event.target.scrollIntoView();
})

console.log("scroll events added in scrollEvents.js")