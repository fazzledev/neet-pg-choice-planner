const PLANNER_URL = "https://neet-pg-choice-planner.fazzle.dev/plan"
const label = (choice) => `${choice.institute} · ${choice.program} · ${choice.quota}`

const host = document.createElement("div")
host.id = "choice-planner-filler"
const shadow = host.attachShadow({ mode: "open" })
shadow.innerHTML = `
  <style>
    :host { all: initial; }
    .panel { position: fixed; right: 16px; bottom: 16px; z-index: 2147483647; width: 340px; max-height: 75vh; display: flex; flex-direction: column; gap: 12px; padding: 14px; border-radius: 16px; background: #101423; color: #fff; font: 500 13px/1.45 system-ui, sans-serif; box-shadow: 0 12px 32px rgba(0,0,0,.35); }
    .panel.collapsed .body { display: none; }
    header { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    strong { font-size: 14px; }
    p { margin: 0; }
    button { font: inherit; border: 1px solid #3a3d78; background: transparent; color: #fff; border-radius: 10px; padding: 7px 12px; cursor: pointer; }
    button:hover:not(:disabled) { background: #3d3bf3; border-color: #3d3bf3; }
    button:disabled { opacity: .45; cursor: default; }
    .body { display: flex; flex-direction: column; gap: 12px; min-height: 0; }
    .muted { color: #aab0c6; }
    .state { font-size: 15px; font-weight: 700; }
    .state.ok { color: #7ee2a8; }
    .state.warn { color: #ffd27a; }
    .actions { display: flex; flex-wrap: wrap; gap: 6px; }
    details { overflow: auto; max-height: 34vh; }
    summary { cursor: pointer; color: #aab0c6; }
    h3 { margin: 8px 0 4px; font-size: 12px; text-transform: uppercase; letter-spacing: .04em; color: #aab0c6; }
    ul { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 3px; }
    li { display: flex; gap: 8px; }
    .rank { flex: none; min-width: 40px; color: #aab0c6; font-variant-numeric: tabular-nums; }
    .message { padding: 8px 10px; border-radius: 10px; background: #1b2038; }
    .message.error { color: #ff9a9a; }
    .confirm { display: flex; flex-direction: column; gap: 8px; padding: 10px; border-radius: 10px; background: #1b2038; }
    [hidden] { display: none !important; }
  </style>
  <section class="panel">
    <header><strong>NEET PG Choice Planner</strong><button type="button" data-action="collapse" aria-label="Collapse">–</button></header>
    <div class="body">
      <p class="muted" data-summary></p>
      <p class="state" data-state></p>
      <details data-details hidden><summary>Show differences</summary><div data-diff></div></details>
      <div class="actions" data-actions hidden>
        <button type="button" data-action="to-mcc">Plan → MCC</button>
        <button type="button" data-action="to-plan">MCC → Plan</button>
        <button type="button" data-action="stop" hidden>Stop</button>
      </div>
      <div class="confirm" data-confirm hidden>
        <p data-confirm-text></p>
        <div class="actions">
          <button type="button" data-action="confirm">Yes, change MCC</button>
          <button type="button" data-action="cancel">Cancel</button>
        </div>
      </div>
      <p class="message" data-message hidden></p>
    </div>
  </section>`
document.documentElement.append(host)

const $ = (selector) => shadow.querySelector(selector)
let order = null
let busy = false
let stopRequested = false
const COPYING = "choice-filler:copying"
const MAX_RESUMES = 3
const USAGE_LIMIT = 50

function sizeBucket(count) {
  if (count === 0) return "0"
  if (count <= 10) return "1-10"
  if (count <= 50) return "11-50"
  if (count <= 200) return "51-200"
  return "201-plus"
}

const firefoxBuild = Boolean(chrome.runtime.getManifest().browser_specific_settings?.gecko)

async function recordUsage(name) {
  if (firefoxBuild) return
  const { usage = [] } = await chrome.storage.local.get("usage")
  await chrome.storage.local.set({ usage: [...usage, name].slice(-USAGE_LIMIT) })
}

function message(text, error = false) {
  const box = $("[data-message]")
  box.hidden = !text
  box.textContent = text || ""
  box.classList.toggle("error", error)
}

function compare() {
  const filled = PortalAdapter.readFilled()
  const filledKeys = new Set(filled.map(choiceKey))
  const plannedKeys = new Set(order.choices.map(choiceKey))
  const missing = order.choices.filter((choice) => !filledKeys.has(choiceKey(choice)))
  const gone = missing.filter((choice) => !PortalAdapter.availableRow(choice))
  const addable = missing.filter((choice) => !gone.includes(choice))
  const numbered = filled.map((choice, index) => ({ ...choice, rank: index + 1 }))
  const extra = numbered.filter((choice) => !plannedKeys.has(choiceKey(choice)))
  const planned = order.choices.filter((choice) => filledKeys.has(choiceKey(choice)))
  const moved = numbered.filter((choice) => plannedKeys.has(choiceKey(choice)))
    .filter((choice, index) => choiceKey(choice) !== choiceKey(planned[index]))
  return { addable, gone, extra, moved }
}

function group(title, items, rank) {
  if (!items.length) return []
  const heading = document.createElement("h3")
  heading.textContent = `${title} (${items.length})`
  const list = document.createElement("ul")
  for (const choice of items) {
    const row = document.createElement("li")
    const number = document.createElement("span")
    number.className = "rank"
    number.textContent = rank(choice)
    const text = document.createElement("span")
    text.textContent = label(choice)
    row.append(number, text)
    list.append(row)
  }
  return [heading, list]
}

function render() {
  if (busy || !$("[data-confirm]").hidden) return
  const state = $("[data-state]")
  const details = $("[data-details]")
  details.hidden = true
  $("[data-actions]").hidden = true
  state.className = "state"

  $("[data-summary]").textContent = order
    ? `Your plan: ${order.choices.length} choices${order.owner ? ` (${order.owner})` : ""}, synced ${new Date(order.sentAt).toLocaleString()}.`
    : "No plan in this browser yet. Open the planner once and it syncs here."

  if (!PortalAdapter.isChoicePage()) {
    state.textContent = "Open Choice Filling to compare."
    return
  }
  if (PortalAdapter.isLocked()) {
    state.textContent = "Your choices are locked. Nothing to copy."
    return
  }

  if (!order) {
    state.textContent = "MCC list found."
    $("[data-actions]").hidden = PortalAdapter.readFilled().length === 0
    $('[data-action="to-mcc"]').disabled = true
    return
  }

  const { addable, gone, extra, moved } = compare()
  const differences = addable.length + gone.length + extra.length + moved.length
  $("[data-actions]").hidden = differences === 0
  $('[data-action="to-mcc"]').disabled = addable.length + extra.length + moved.length === 0
  $('[data-action="to-plan"]').disabled = false
  if (!differences) {
    state.textContent = "In sync ✓"
    state.classList.add("ok")
    return
  }
  state.textContent = `${differences} ${differences === 1 ? "difference" : "differences"}`
  state.classList.add("warn")
  $("[data-diff]").replaceChildren(
    ...group("In your plan, not on MCC yet", addable, (c) => `#${c.rank}`),
    ...group("In your plan, but MCC no longer offers it", gone, (c) => `#${c.rank}`),
    ...group("On MCC at a different rank", moved, (c) => `MCC #${c.rank}`),
    ...group("Saved on MCC, not in your plan", extra, (c) => `MCC #${c.rank}`),
  )
  details.hidden = false
}

function stopIfAsked() {
  if (stopRequested) throw new Error("you pressed Stop")
}

function askToCopy() {
  const { addable, gone, extra, moved } = compare()
  const steps = [addable.length && `add ${addable.length}`, extra.length && `remove ${extra.length}`, moved.length && `move ${moved.length}`].filter(Boolean).join(", ")
  const unavailable = gone.length ? ` ${gone.length} from your plan can't be added because MCC no longer offers ${gone.length === 1 ? "it" : "them"}.` : ""
  $("[data-confirm-text]").textContent = `MCC will become a copy of your plan: ${steps}.${unavailable} Nothing is saved until you press Save and Continue and enter the OTP.`
  $("[data-confirm]").hidden = false
  $("[data-actions]").hidden = true
}

function closeConfirm() {
  $("[data-confirm]").hidden = true
  render()
}

async function copyToMcc(resumes = 0) {
  busy = true
  stopRequested = false
  sessionStorage.setItem(COPYING, String(resumes))
  $("[data-confirm]").hidden = true
  $("[data-actions]").hidden = false
  $('[data-action="to-mcc"]').disabled = true
  $('[data-action="to-plan"]').disabled = true
  $('[data-action="stop"]').hidden = false
  try {
    const { extra } = compare()
    for (const [index, choice] of extra.entries()) {
      stopIfAsked()
      message(`Removing ${index + 1} of ${extra.length}…`)
      await PortalAdapter.remove(choice)
    }
    const { addable, gone } = compare()
    for (const [index, choice] of addable.entries()) {
      stopIfAsked()
      message(`Adding ${index + 1} of ${addable.length}…`)
      await PortalAdapter.add(choice)
    }
    const present = new Set(PortalAdapter.readFilled().map(choiceKey))
    const target = order.choices.map(choiceKey).filter((key) => present.has(key))
    for (let index = 0; index < target.length; index++) {
      message(`Arranging ${index + 1} of ${target.length}…`)
      let at = PortalAdapter.readFilled().map(choiceKey).indexOf(target[index])
      while (at > index) {
        stopIfAsked()
        await PortalAdapter.moveUp(at--)
      }
    }
    const skipped = gone.length ? ` ${gone.length} ${gone.length === 1 ? "choice" : "choices"} from your plan MCC no longer offers ${gone.length === 1 ? "was" : "were"} skipped.` : ""
    recordUsage(`extension/filled-mcc/${sizeBucket(target.length)}`).catch(() => {})
    message(`MCC now matches your plan.${skipped} Check it, then press Save and Continue and enter the OTP. Nothing is saved until you do.`)
  } catch (error) {
    message(`Stopped: ${error.message}. Nothing has been saved; reload the page to undo the changes.`, true)
  } finally {
    sessionStorage.removeItem(COPYING)
    $('[data-action="stop"]').hidden = true
    busy = false
    render()
  }
}

async function importFromMcc() {
  const choices = PortalAdapter.readFilled().map((choice, index) => ({ ...choice, rank: index + 1 }))
  await chrome.storage.local.set({ portalImport: { choices, readAt: new Date().toISOString() } })
  recordUsage("extension/read-mcc").catch(() => {})
  message(`Read ${choices.length} choices from MCC. Confirm in the planner tab that just opened; your plan changes only when you press Replace there.`)
  window.open(PLANNER_URL, "_blank", "noopener")
}

shadow.addEventListener("click", (event) => {
  const action = event.target.closest("button")?.dataset.action
  if (action === "collapse") $(".panel").classList.toggle("collapsed")
  if (action === "to-mcc") askToCopy()
  if (action === "confirm") copyToMcc()
  if (action === "cancel") closeConfirm()
  if (action === "stop") stopRequested = true
  if (action === "to-plan") importFromMcc().catch((error) => message(error.message, true))
})

let renderTimer
new MutationObserver(() => {
  clearTimeout(renderTimer)
  renderTimer = setTimeout(render, 200)
}).observe(document.body, { childList: true, subtree: true })

chrome.storage.local.get("order").then((stored) => {
  order = stored.order || null
  render()
  const resumes = sessionStorage.getItem(COPYING)
  if (resumes === null || !order || !PortalAdapter.isChoicePage()) return
  if (Number(resumes) >= MAX_RESUMES) {
    sessionStorage.removeItem(COPYING)
    message("Plan → MCC stopped: the page kept reloading. Nothing has been saved.", true)
    return
  }
  copyToMcc(Number(resumes) + 1)
})

chrome.storage.onChanged.addListener((changes) => {
  if (!changes.order) return
  order = changes.order.newValue
  render()
})
