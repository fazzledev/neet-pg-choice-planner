(() => {
  const storageKey = "planner:presence-tab"
  const intervalMs = 60_000

  const tabId = (() => {
    try {
      const existing = sessionStorage.getItem(storageKey)
      if (existing) return existing
      const fresh = crypto.randomUUID()
      sessionStorage.setItem(storageKey, fresh)
      return fresh
    } catch {
      return crypto.randomUUID()
    }
  })()

  const ping = () => {
    if (document.visibilityState !== "visible") return
    fetch("/presence", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      credentials: "same-origin",
      body: JSON.stringify({ tab_id: tabId }),
      keepalive: true,
    }).catch(() => {})
  }

  ping()
  setInterval(ping, intervalMs)
  document.addEventListener("visibilitychange", ping)
})()
