document.documentElement.dataset.choiceFiller = "1"

document.addEventListener("choice-planner:order", async (event) => {
  const order = JSON.parse(event.detail)
  await chrome.storage.local.set({ order })
  document.dispatchEvent(new CustomEvent("choice-filler:saved", { detail: String(order.choices.length) }))
})

document.dispatchEvent(new CustomEvent("choice-filler:ready"))
