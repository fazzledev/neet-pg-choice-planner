{
  const video = document.querySelector(".lp-demo-video")
  const roomy = window.matchMedia("(min-width: 900px)").matches
  const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const saveData = navigator.connection?.saveData

  if (video && roomy && !calm && !saveData) video.play().catch(() => {})

  const rotating = document.querySelector(".lp-rotate")
  let shown = 0

  if (rotating && !calm) {
    for (const word of rotating.dataset.more.split(" ")) {
      const span = document.createElement("span")
      span.setAttribute("aria-hidden", "true")
      span.textContent = word
      rotating.append(span)
    }
    const words = [...rotating.children]

    setInterval(() => {
      words[shown].classList.remove("on")
      shown = (shown + 1) % words.length
      words[shown].classList.add("on")
    }, 2200)
  }
}
