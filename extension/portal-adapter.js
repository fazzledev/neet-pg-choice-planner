const FORBIDDEN_CONTROL = /lock|final\s*submit|freeze/i
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

async function waitFor(check, timeout = 2000) {
  for (let waited = 0; waited <= timeout; waited += 50) {
    if (check()) return true
    await pause(50)
  }
  return false
}

const choiceKey = (choice) => `${choice.instcd}|${choice.brcd}|${choice.quota}`.toLowerCase()

const PortalAdapter = {
  isChoicePage() {
    return Boolean(document.querySelector("#filledChoiceContainer") && document.querySelector("#avlChoiceContainer"))
  },

  isLocked() {
    return this.isChoicePage() && !document.querySelector("#avlChoiceContainer .aChoice") && !document.querySelector("#filledChoiceContainer .Up")
  },

  rows(tableId) {
    return [...document.querySelectorAll(`#${tableId} tr`)].filter((row) => row.cells.length > 5 && !row.querySelector("th"))
  },

  rowChoice(row) {
    const cell = (index) => row.cells[index]?.textContent.trim() || ""
    return { instcd: cell(0), brcd: cell(2), quota: cell(5), institute: cell(1), program: cell(3) }
  },

  readFilled() {
    return this.rows("filledChoiceContainer").map((row) => this.rowChoice(row))
  },

  availableRow(choice) {
    const wanted = choiceKey(choice)
    return this.rows("avlChoiceContainer").find((row) => choiceKey(this.rowChoice(row)) === wanted)
  },

  async add(choice) {
    const button = this.availableRow(choice)?.querySelector("input.aChoice, button.aChoice")
    if (!button) throw new Error(`#${choice.rank} ${choice.institute} is not on MCC's list`)
    const before = this.readFilled().length
    this.safeClick(button)
    if (!(await waitFor(() => this.readFilled().length > before))) throw new Error(`MCC did not add #${choice.rank} ${choice.institute}`)
  },

  async moveUp(index) {
    const row = this.rows("filledChoiceContainer")[index]
    const button = row?.querySelector("input.Up, button.Up")
    if (!button) throw new Error(`No Up button on MCC row ${index + 1}`)
    const key = choiceKey(this.rowChoice(row))
    this.safeClick(button)
    const moved = () => { const above = this.rows("filledChoiceContainer")[index - 1]; return above && choiceKey(this.rowChoice(above)) === key }
    if (!(await waitFor(moved))) throw new Error(`MCC did not move row ${index + 1} up`)
  },

  safeClick(element) {
    const label = `${element.value || ""} ${element.textContent || ""} ${element.id || ""} ${element.name || ""} ${element.getAttribute("href") || ""}`
    if (FORBIDDEN_CONTROL.test(label)) throw new Error(`Refusing to press "${label.trim()}"`)
    element.click()
  },
}
