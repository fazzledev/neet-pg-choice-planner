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

async function offerImport() {
  if (!extensionAlive()) return
  const { portalImport } = await chrome.storage.local.get("portalImport")
  if (portalImport) document.dispatchEvent(new CustomEvent("choice-filler:import", { detail: JSON.stringify(portalImport) }))
}

async function handOverUsage() {
  if (!extensionAlive()) return
  const { usage } = await chrome.storage.local.get("usage")
  if (!usage?.length) return
  await chrome.storage.local.remove("usage")
  document.dispatchEvent(new CustomEvent("choice-filler:usage", { detail: JSON.stringify(usage) }))
}

document.addEventListener("choice-planner:listening", () => {
  offerImport().catch(() => {})
  handOverUsage().catch(() => {})
})

document.addEventListener("choice-planner:import-done", () => {
  if (extensionAlive()) chrome.storage.local.remove("portalImport").catch(() => {})
})


document.dispatchEvent(new CustomEvent("choice-filler:ready"))
