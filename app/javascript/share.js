{
  const resetTimers = new WeakMap()

  for (const menu of document.querySelectorAll(".share-menu")) {
    const { shareUrl: url, shareTitle: title, shareText: text } = menu.dataset
    const summary = menu.querySelector("summary")
    const input = menu.querySelector(".share-link input")
    const copy = menu.querySelector(".share-copy")
    const status = menu.querySelector(".share-status")

    if (navigator.share) {
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

    copy.addEventListener("click", async () => {
      clearTimeout(resetTimers.get(copy))
      try {
        await navigator.clipboard.writeText(url)
        copy.textContent = "Copied"
        copy.dataset.copied = "1"
        status.textContent = "Link copied. Paste it in a chat or email."
      } catch {
        input.focus()
        status.textContent = "Couldn't copy automatically. The link is selected, so copy it with your keyboard."
      }
      resetTimers.set(copy, setTimeout(() => {
        copy.textContent = "Copy"
        delete copy.dataset.copied
        status.textContent = ""
      }, 4000))
    })
  }
}
