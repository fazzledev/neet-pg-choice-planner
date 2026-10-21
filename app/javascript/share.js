for (const button of document.querySelectorAll("[data-share-url]")) {
  button.addEventListener("click", async () => {
    const { shareUrl: url, shareTitle: title, shareText: text } = button.dataset
    if (navigator.share) {
      await navigator.share({ title, text, url }).catch(() => {})
      return
    }
    await navigator.clipboard.writeText(url)
    button.dataset.copied = "1"
    setTimeout(() => delete button.dataset.copied, 1500)
  })
}
