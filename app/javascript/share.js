{
  const resetTimers = new WeakMap()

  for (const menu of document.querySelectorAll(".share-menu")) {
    const { shareUrl: url, shareTitle: title, shareText: text } = menu.dataset
    const summary = menu.querySelector("summary")
    const input = menu.querySelector(".share-link input")
    const copy = menu.querySelector(".share-copy")
    const status = menu.querySelector(".share-status")

    if (navigator.share && matchMedia("(pointer: coarse)").matches) {
      summary.addEventListener("click", async (event) => {
        if (menu.open) return
        event.preventDefault()
        try {
          await navigator.share({ title, text, url })
        } catch (error) {
          if (error.name !== "AbortError") menu.open = true
        }
      })
    }

    input.addEventListener("focus", () => input.select())

    const resetCopy = () => {
      clearTimeout(resetTimers.get(copy))
      copy.textContent = "Copy"
      delete copy.dataset.copied
      status.classList.remove("failed")
      status.textContent = ""
    }

    menu.addEventListener("toggle", () => { if (!menu.open) resetCopy() })

    copy.addEventListener("click", async () => {
      resetCopy()
      try {
        await navigator.clipboard.writeText(url)
      } catch {
        input.focus()
        status.classList.add("failed")
        status.textContent = "Couldn't copy automatically. The link is selected, so copy it with your keyboard."
        return
      }
      copy.textContent = "Copied"
      copy.dataset.copied = "1"
      status.textContent = "Link copied. Paste it in a chat or email."
      resetTimers.set(copy, setTimeout(resetCopy, 4000))
    })
  }
}
