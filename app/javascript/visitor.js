(() => {
  const storageKey = "planner:visitor"
  const today = () => new Date().toLocaleDateString("en-CA")

  const read = () => {
    try {
      return JSON.parse(localStorage.getItem(storageKey))
    } catch {
      return undefined
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
    if (seen === undefined || seen?.lastCounted === today()) return
    const name = seen ? "visitor/returning" : "visitor/first"
    if (!write({ lastCounted: today() })) return
    window.goatcounter.count({ path: name, title: name, event: true })
  }

  if (document.readyState === "complete") countVisit()
  else window.addEventListener("load", countVisit, { once: true })
})()
