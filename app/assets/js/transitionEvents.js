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

window.addEventListener("phx:highlight_shared", (event) => {
    document.querySelectorAll(event.detail.selector).forEach(el => {
        const tagElement = el.querySelector("p")
        if (tagElement) {
            // Add pulse animation class
            tagElement.classList.add("animate-pulse")
            
            // Add a brief scale and glow animation
            tagElement.style.transform = "scale(1.15)"
            tagElement.style.transition = "transform 0.3s ease-out, box-shadow 0.3s ease-out"
            tagElement.style.boxShadow = "0 0 20px rgba(34, 197, 94, 0.6)"
            
            // Remove pulse after 2 seconds
            setTimeout(() => {
                tagElement.classList.remove("animate-pulse")
            }, 2000)
            
            // Reset scale and glow after animation
            setTimeout(() => {
                tagElement.style.transform = "scale(1)"
                setTimeout(() => {
                    tagElement.style.boxShadow = ""
                }, 300)
            }, 500)
        }
    })
});
