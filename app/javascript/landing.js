{
  const video = document.querySelector(".lp-demo-video")
  const roomy = window.matchMedia("(min-width: 900px)").matches
  const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const saveData = navigator.connection?.saveData

  if (video && roomy && !calm && !saveData) video.play().catch(() => {})

  const rotating = document.querySelector(".lp-rotate")
  const words = rotating?.dataset.words.split(" ") ?? []
  let shown = 0

  if (rotating && !calm) {
    setInterval(() => {
      rotating.classList.add("out")
      setTimeout(() => {
        shown = (shown + 1) % words.length
        rotating.textContent = words[shown]
        rotating.classList.remove("out")
      }, 250)
    }, 2200)
  }
}
