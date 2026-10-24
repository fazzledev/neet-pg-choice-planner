{
  const video = document.querySelector(".lp-demo-video")
  const roomy = window.matchMedia("(min-width: 900px)").matches
  const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  const saveData = navigator.connection?.saveData

  if (video && roomy && !calm && !saveData) video.play().catch(() => {})

  const compare = document.querySelector(".lp-compare")

  if (compare) {
    const pin = compare.querySelector(".lp-compare-pin")
    const cards = [...compare.querySelectorAll(".lp-flip")]
    const buttons = [...compare.querySelectorAll("[data-show]")]
    let stopFollowingScroll = () => {}

    const show = (view, targets = cards) => {
      targets.forEach((card) => { card.dataset.view = view })
      compare.dataset.view = view
      buttons.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.show === view)))
    }

    buttons.forEach((button) => button.addEventListener("click", () => {
      stopFollowingScroll()
      show(button.dataset.show)
    }))

    const pinnable = window.matchMedia("(min-width: 1101px) and (min-height: 860px)").matches

    if (!calm && pinnable) {
      compare.classList.add("pinned")
      pin.style.top = `${Math.max(24, (window.innerHeight - pin.offsetHeight) / 2)}px`
      let shown = null
      const follow = () => {
        const travel = compare.offsetHeight - pin.offsetHeight
        const progress = (parseFloat(pin.style.top) - compare.getBoundingClientRect().top) / travel
        const view = progress > 0.4 ? "planner" : "portal"
        if (view !== shown) show(shown = view)
      }
      window.addEventListener("scroll", follow, { passive: true })
      stopFollowingScroll = () => window.removeEventListener("scroll", follow)
      follow()
    } else if (!calm) {
      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) show("planner", [entry.target])
          else if (entry.boundingClientRect.top > 0) show("portal", [entry.target])
        })
      }, { rootMargin: "0px 0px -40% 0px" })
      show("portal")
      cards.forEach((card) => observer.observe(card))
      stopFollowingScroll = () => observer.disconnect()
    }
  }
}
