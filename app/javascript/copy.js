for (const button of document.querySelectorAll("[data-copy]")) {
  const status = button.dataset.copyStatus && document.querySelector(button.dataset.copyStatus)
  const field = button.closest("div")?.querySelector("input[readonly]")
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy)
      button.dataset.copied = "1"
      if (status) status.textContent = "Copied. Paste it into your assistant."
      setTimeout(() => delete button.dataset.copied, 1500)
    } catch {
      field?.select()
      if (status) status.textContent = field ? "Couldn't copy. The link is selected, so copy it by hand." : "Couldn't copy. Use Ask ChatGPT or Ask Claude instead."
    }
  })
}
