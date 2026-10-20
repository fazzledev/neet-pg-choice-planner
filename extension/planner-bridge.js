const extensionAlive = () => Boolean(globalThis.chrome?.runtime?.id)

document.documentElement.dataset.choiceFiller = "1"

document.addEventListener("choice-planner:order", async (event) => {
  if (!extensionAlive()) return
  const order = JSON.parse(event.detail)
  try {
    await chrome.storage.local.set({ order })
  } catch {
    return
  }
  document.dispatchEvent(new CustomEvent("choice-filler:saved", { detail: String(order.choices.length) }))
})

document.dispatchEvent(new CustomEvent("choice-filler:ready"))
