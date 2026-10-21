{
  for (const box of document.querySelectorAll(".link-copy")) {
    const input = box.querySelector("input")
    const copy = box.querySelector("button")
    const status = box.nextElementSibling
    let resetTimer

    const reset = () => {
      clearTimeout(resetTimer)
      copy.textContent = "Copy"
      delete copy.dataset.copied
      status.classList.remove("failed")
      status.textContent = ""
    }

    input.addEventListener("focus", () => input.select())

    copy.addEventListener("click", async () => {
      reset()
      try {
        await navigator.clipboard.writeText(input.value)
      } catch {
        input.focus()
        status.classList.add("failed")
        status.textContent = "Couldn't copy automatically. The link is selected: press and hold it to copy."
        return
      }
      copy.textContent = "Copied"
      copy.dataset.copied = "1"
      status.textContent = "Link copied. Paste it into a chat or email to yourself, then open it on your computer."
      resetTimer = setTimeout(reset, 6000)
    })
  }
}
