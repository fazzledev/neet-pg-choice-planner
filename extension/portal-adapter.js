const FORBIDDEN_CONTROL = /lock|final\s*submit|freeze/i

const PortalAdapter = {
  ready: false,

  isChoicePage() {
    return false
  },

  readFilled() {
    return []
  },

  async add(choice) {
    throw new Error(`The portal layout is not mapped yet, so ${choice.institute} was not added`)
  },

  safeClick(element) {
    const label = `${element.value || ""} ${element.textContent || ""} ${element.id || ""} ${element.name || ""}`
    if (FORBIDDEN_CONTROL.test(label)) throw new Error(`Refusing to press "${label.trim()}"`)
    element.click()
  },
}
