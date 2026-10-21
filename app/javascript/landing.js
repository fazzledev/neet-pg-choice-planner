{
  const video = document.querySelector(".lp-demo-video")
  const roomy = window.matchMedia("(min-width: 900px)").matches
  const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const saveData = navigator.connection?.saveData

  if (video && roomy && !calm && !saveData) video.play().catch(() => {})
}
