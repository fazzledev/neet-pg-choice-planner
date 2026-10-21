const copiedTimers = new WeakMap()

function showCopied(button, status) {
  button.dataset.copied = "1"
  status.textContent = "Link copied"
  clearTimeout(copiedTimers.get(button))
  copiedTimers.set(button, setTimeout(() => {
    delete button.dataset.copied
    status.textContent = ""
  }, 1500))
}

async function copyLink(button, status, url) {
  try {
    await navigator.clipboard.writeText(url)
    showCopied(button, status)
  } catch {
    prompt("Copy this link", url)
  }
}

for (const button of document.querySelectorAll("[data-share-url]")) {
  const status = document.createElement("span")
  status.className = "visually-hidden"
  status.setAttribute("role", "status")
  button.after(status)

  button.addEventListener("click", async () => {
    const { shareUrl: url, shareTitle: title, shareText: text } = button.dataset
    if (navigator.share) {
      try {
        await navigator.share({ title, text, url })
        return
      } catch (error) {
        if (error.name === "AbortError") return
      }
    }
    await copyLink(button, status, url)
  })
}
