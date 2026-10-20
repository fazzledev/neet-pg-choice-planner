const FORBIDDEN_CONTROL = /lock|final\s*submit|freeze/i

const PortalAdapter = {
  ready: true,

  isChoicePage() {
    return Boolean(document.querySelector("#filledChoiceContainer") && document.querySelector("#avlChoiceContainer"))
  },

  rowChoice(row) {
    const cell = (index) => row.cells[index]?.textContent.trim() || ""
    return { instcd: cell(0), brcd: cell(2), quota: cell(5), institute: cell(1), program: cell(3) }
  },

  rows(tableId) {
    return [...document.querySelectorAll(`#${tableId} tr`)].filter((row) => row.cells.length > 5 && !row.querySelector("th"))
  },

  readFilled() {
    return this.rows("filledChoiceContainer").map((row) => this.rowChoice(row))
  },

  async add(choice) {
    const wanted = `${choice.instcd}|${choice.brcd}|${choice.quota}`.toLowerCase()
    const row = this.rows("avlChoiceContainer").find((candidate) => {
      const found = this.rowChoice(candidate)
      return `${found.instcd}|${found.brcd}|${found.quota}`.toLowerCase() === wanted
    })
    if (!row) throw new Error(`#${choice.rank} ${choice.institute} is not in the portal's available list`)

    const button = row.querySelector("input.aChoice, button.aChoice")
    if (!button) throw new Error(`#${choice.rank} has no Add button on the portal`)

    const before = this.readFilled().length
    this.safeClick(button)
    await new Promise((resolve) => setTimeout(resolve, 400))
    if (this.readFilled().length <= before) throw new Error(`The portal did not add #${choice.rank} ${choice.institute}`)
  },

  safeClick(element) {
    const label = `${element.value || ""} ${element.textContent || ""} ${element.id || ""} ${element.name || ""} ${element.getAttribute("href") || ""}`
    if (FORBIDDEN_CONTROL.test(label)) throw new Error(`Refusing to press "${label.trim()}"`)
    element.click()
  },
}
