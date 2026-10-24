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
      const flipped = cards.filter((card) => card.dataset.view !== "portal").length
      const shown = flipped > cards.length / 2 ? "planner" : "portal"
      compare.dataset.view = shown
      buttons.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.show === shown)))
    }

    const followPinned = () => {
      const follow = () => {
        const travel = compare.offsetHeight - pin.offsetHeight
        const progress = (parseFloat(pin.style.top) - compare.getBoundingClientRect().top) / travel
        cards.forEach((card, index) => {
          const view = progress > 0.2 + index * 0.08 ? "planner" : "portal"
          if (card.dataset.view !== view) show(view, [card])
        })
      }
      window.addEventListener("scroll", follow, { passive: true })
      follow()
      return () => window.removeEventListener("scroll", follow)
    }

    const followEachCard = () => {
      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) show("planner", [entry.target])
          else if (entry.boundingClientRect.top > 0) show("portal", [entry.target])
        })
      }, { rootMargin: "0px 0px -40% 0px" })
      cards.forEach((card) => observer.observe(card))
      return () => observer.disconnect()
    }

    const pinnable = window.matchMedia("(min-width: 1101px) and (min-height: 860px)")
    let following = !calm

    const followScroll = () => {
      stopFollowingScroll()
      compare.classList.remove("pinned")
      pin.style.top = ""
      if (!following) return

      if (pinnable.matches) {
        compare.classList.add("pinned")
        const top = (window.innerHeight - pin.offsetHeight) / 2
        if (top >= 24) {
          pin.style.top = `${top}px`
          stopFollowingScroll = followPinned()
          return
        }
        compare.classList.remove("pinned")
      }
      stopFollowingScroll = followEachCard()
    }

    buttons.forEach((button) => button.addEventListener("click", () => {
      following = false
      followScroll()
      show(button.dataset.show)
    }))

    let resizing
    window.addEventListener("resize", () => {
      clearTimeout(resizing)
      resizing = setTimeout(followScroll, 200)
    })

    followScroll()
  }
}
