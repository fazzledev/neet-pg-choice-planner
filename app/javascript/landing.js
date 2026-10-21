const video = document.querySelector(".lp-demo-video")
const roomy = window.matchMedia("(min-width: 900px)").matches
const saveData = navigator.connection?.saveData

if (video && roomy && !saveData) {
  video.removeAttribute("controls")
  video.preload = "auto"
  video.play().catch(() => video.setAttribute("controls", ""))
}
