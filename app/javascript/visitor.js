(() => {
  const storageKey = "planner:visitor"
  const today = () => new Date().toLocaleDateString("en-CA")

  const read = () => {
    let raw
    try {
      raw = localStorage.getItem(storageKey)
    } catch {
      return undefined
    }
    try {
      return JSON.parse(raw)
    } catch {
      return {}
    }
  }

  const write = (value) => {
    try {
      localStorage.setItem(storageKey, JSON.stringify(value))
      return true
    } catch {
      return false
    }
  }

  const countVisit = () => {
    if (!navigator.onLine || !window.goatcounter?.count) return
    const seen = read()
    if (seen === undefined || seen?.lastCounted === today() || window.goatcounter.filter?.()) return
    const name = seen ? "visitor/returning" : "visitor/first"
    if (!write({ lastCounted: today() })) return
    window.goatcounter.count({ path: name, title: name, event: true })
  }

  const countWhenVisible = () => {
    if (document.visibilityState === "visible") return countVisit()
    document.addEventListener("visibilitychange", countWhenVisible, { once: true })
  }

  if (document.readyState === "complete") countWhenVisible()
  else window.addEventListener("load", countWhenVisible, { once: true })
})()
