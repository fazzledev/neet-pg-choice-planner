const root = document.querySelector(".practice")
const STORAGE_KEY = "practice-choice-filling"
const SERVER_DELAY_MS = 150

const filledBody = root.querySelector("[data-filled]")
const availableBody = root.querySelector("[data-available]")
const statusLine = root.querySelector("[data-status]")
const filterInput = root.querySelector("[data-filter]")

let choices = []
let byId = new Map()
let state = { filled: [], locked: false }
let lockArmed = false
let busy = false

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null")
    if (saved) state = { ...state, ...saved }
  } catch {}
  state.filled = state.filled.filter((id) => byId.has(id))
}

function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
  } catch {}
}

function say(text) {
  statusLine.textContent = text
}

function buildChoices(catalog) {
  const institutes = new Map(catalog.institutes.map(([code, name, , typeCode]) => [code, { name, typeName: catalog.institute_types[typeCode] || typeCode }]))
  choices = catalog.choices.map(([id, instcd, brcd, quota]) => {
    const institute = institutes.get(instcd) || { name: instcd, typeName: "" }
    const [program] = catalog.programs[brcd] || [brcd]
    return { id, instcd, brcd, quota, program, institute: institute.name, typeName: institute.typeName }
  })
  byId = new Map(choices.map((choice) => [choice.id, choice]))
}

function actionButton(className, value) {
  const button = document.createElement("input")
  button.type = "button"
  button.className = className
  button.value = value
  return button
}

function choiceRow(choice, buttons) {
  const row = document.createElement("tr")
  row.dataset.choiceId = choice.id
  for (const text of [choice.instcd, choice.institute, choice.brcd, choice.program, choice.typeName, choice.quota]) {
    const cell = document.createElement("td")
    cell.textContent = text
    row.append(cell)
  }
  const actions = document.createElement("td")
  actions.append(...buttons)
  row.append(actions)
  return row
}

function emptyRow() {
  const row = document.createElement("tr")
  const cell = document.createElement("td")
  cell.colSpan = 7
  cell.className = "practice-empty"
  cell.textContent = "No choices filled yet. Add them from the list below, or let the extension copy your plan."
  row.append(cell)
  return row
}

function render() {
  const filledIds = new Set(state.filled)
  filledBody.replaceChildren(...(state.filled.length ? state.filled.map((id, index) => {
    const buttons = state.locked ? [] : [index > 0 && actionButton("Up", "Up"), actionButton("fChoice", "Remove")].filter(Boolean)
    return choiceRow(byId.get(id), buttons)
  }) : [emptyRow()]))
  availableBody.replaceChildren(...choices.filter((choice) => !filledIds.has(choice.id))
    .map((choice) => choiceRow(choice, state.locked ? [] : [actionButton("aChoice", "Add")])))
  root.querySelector("[data-filled-count]").textContent = `(${state.filled.length})`
  root.querySelector("[data-available-count]").textContent = `(${choices.length - state.filled.length})`
  for (const control of root.querySelectorAll('[data-practice="save"], [data-practice="lock"]')) control.disabled = state.locked
  applyFilter()
}

function applyFilter() {
  const words = filterInput.value.toLowerCase().split(/\s+/).filter(Boolean)
  for (const row of availableBody.rows) {
    const text = row.textContent.toLowerCase()
    row.hidden = !words.every((word) => text.includes(word))
  }
}

function change(update) {
  if (busy || state.locked) return
  busy = true
  lockArmed = false
  setTimeout(() => {
    update()
    saveState()
    busy = false
    render()
  }, SERVER_DELAY_MS)
}

root.addEventListener("click", (event) => {
  const control = event.target.closest("input[type=button], button")
  if (!control) return
  const id = Number(control.closest("tr")?.dataset.choiceId)

  if (control.classList.contains("aChoice")) {
    change(() => state.filled.push(id))
    say("")
  }
  if (control.classList.contains("fChoice")) {
    change(() => { state.filled = state.filled.filter((filledId) => filledId !== id) })
    say("")
  }
  if (control.classList.contains("Up")) {
    change(() => {
      const at = state.filled.indexOf(id)
      if (at > 0) [state.filled[at - 1], state.filled[at]] = [state.filled[at], state.filled[at - 1]]
    })
    say("")
  }

  const action = control.dataset.practice
  if (action === "save") {
    lockArmed = false
    say(`Saved ${state.filled.length} choices. On MCC you would now enter the OTP sent to your phone; here nothing else happens.`)
  }
  if (action === "lock") {
    if (!lockArmed) {
      lockArmed = true
      say("Press Lock choices again to lock. On MCC locking is final and can't be undone. Here, Start over unlocks it.")
      return
    }
    lockArmed = false
    state.locked = true
    saveState()
    render()
    say("Locked. On MCC your choices could no longer change. Press Start over to practise again.")
  }
  if (action === "reset") {
    lockArmed = false
    state = { filled: [], locked: false }
    saveState()
    render()
    say("Started over with an empty list.")
  }
})

filterInput.addEventListener("input", applyFilter)

async function start() {
  say("Loading this year's choices…")
  const response = await fetch(root.dataset.catalogUrl, { headers: { Accept: "application/json" } })
  buildChoices(await response.json())
  loadState()
  render()
  say(state.locked ? "Locked. Press Start over to practise again." : "")
}

start().catch(() => say("Couldn't load the choices. Reload the page to try again."))
