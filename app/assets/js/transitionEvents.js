window.addEventListener("phx:show", (event) => {
    document.querySelectorAll(event.detail.selector).forEach(el => {
        js = el.getAttribute("data-show")
        if (js) {
            window.liveSocket.execJS(el, js)
        }
    })
});

window.addEventListener("phx:hide", (event) => {
    document.querySelectorAll(event.detail.selector).forEach(el => {
        js = el.getAttribute("data-hide")
        if (js) {
            window.liveSocket.execJS(el, js)
        }
    })
});
