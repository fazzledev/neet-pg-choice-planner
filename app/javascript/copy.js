for (const button of document.querySelectorAll("[data-copy]")) {
  button.addEventListener("click", async () => {
    await navigator.clipboard.writeText(button.dataset.copy)
    button.dataset.copied = "1"
    setTimeout(() => delete button.dataset.copied, 1500)
  })
}
