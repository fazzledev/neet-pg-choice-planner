{
  const video = document.querySelector(".lp-demo-video")
  const roomy = window.matchMedia("(min-width: 900px)").matches
  const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const saveData = navigator.connection?.saveData

  if (video && roomy && !calm && !saveData) video.play().catch(() => {})

  const words = [...document.querySelectorAll(".lp-rotate > span")]
  let shown = 0

  if (words.length > 1 && !calm) {
    setInterval(() => {
      words[shown].classList.remove("on")
      shown = (shown + 1) % words.length
      words[shown].classList.add("on")
    }, 2200)
  }
}
