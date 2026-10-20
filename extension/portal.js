const key = (choice) => `${choice.instcd}|${choice.brcd}|${choice.quota}`.toLowerCase()

const host = document.createElement("div")
host.id = "choice-planner-filler"
const shadow = host.attachShadow({ mode: "open" })
shadow.innerHTML = `
  <style>
    :host { all: initial; }
    .panel { position: fixed; right: 16px; bottom: 16px; z-index: 2147483647; width: 320px; max-height: 70vh; display: flex; flex-direction: column; gap: 10px; padding: 14px; border-radius: 16px; background: #101423; color: #fff; font: 500 13px/1.4 system-ui, sans-serif; box-shadow: 0 12px 32px rgba(0,0,0,.35); }
    .panel.collapsed .body { display: none; }
    header { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    strong { font-size: 14px; }
    button { font: inherit; border: 1px solid #3a3d78; background: transparent; color: #fff; border-radius: 10px; padding: 6px 10px; cursor: pointer; }
    button:hover:not(:disabled) { background: #3d3bf3; border-color: #3d3bf3; }
    button:disabled { opacity: .45; cursor: default; }
    .body { display: flex; flex-direction: column; gap: 10px; min-height: 0; }
    .actions { display: flex; flex-wrap: wrap; gap: 6px; }
    .muted { color: #aab0c6; }
    .log { overflow: auto; max-height: 30vh; margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 4px; }
    .log li.error { color: #ff9a9a; }
  </style>
  <section class="panel">
    <header><strong>Choice Planner filler</strong><button type="button" data-action="collapse" aria-label="Collapse">–</button></header>
    <div class="body">
      <p class="muted" data-summary>Loading your order…</p>
      <div class="actions">
        <button type="button" data-action="compare">Compare</button>
        <button type="button" data-action="fill-next">Add next</button>
        <button type="button" data-action="inspect">Inspect page</button>
      </div>
      <ul class="log" data-log></ul>
    </div>
  </section>`
document.documentElement.append(host)

const $ = (selector) => shadow.querySelector(selector)
let order = null

function log(text, error = false) {
  const item = document.createElement("li")
  item.textContent = text
  item.classList.toggle("error", error)
  $("[data-log]").prepend(item)
}

function missing() {
  const filled = new Set(PortalAdapter.readFilled().map(key))
  return order.choices.filter((choice) => !filled.has(key(choice)))
}

function refresh() {
  const mapped = PortalAdapter.ready && PortalAdapter.isChoicePage()
  $("[data-summary]").textContent = !order
    ? "No order yet. Open Choice Planner in this browser and it syncs here."
    : `${order.choices.length} choices from Choice Planner${order.owner ? ` (${order.owner})` : ""}, synced ${new Date(order.sentAt).toLocaleString()}.${mapped ? "" : " Open Choice Filling to compare and add."}`
  $('[data-action="compare"]').disabled = !order || !mapped
  $('[data-action="fill-next"]').disabled = !order || !mapped
}

function compare() {
  const filled = PortalAdapter.readFilled()
  const wanted = new Set(order.choices.map(key))
  const extra = filled.filter((choice) => !wanted.has(key(choice)))
  const positions = order.choices.map((choice) => filled.findIndex((f) => key(f) === key(choice))).filter((index) => index !== -1)
  const outOfOrder = positions.filter((position, index) => index > 0 && position < positions[index - 1])
  log(`Portal has ${filled.length}, missing ${missing().length}, not in your order ${extra.length}, out of order ${outOfOrder.length}.`)
}

async function fillNext() {
  const next = missing()[0]
  if (!next) return log("Nothing left to add.")
  try {
    await PortalAdapter.add(next)
    log(`Added #${next.rank} ${next.institute} · ${next.program} · ${next.quota}`)
  } catch (error) {
    log(error.message, true)
  }
}

function describe(element) {
  return {
    tag: element.tagName.toLowerCase(),
    id: element.id || undefined,
    name: element.getAttribute("name") || undefined,
    type: element.getAttribute("type") || undefined,
    label: element.matches("button, a, input[type=submit], input[type=button]") ? (element.value || element.textContent || "").trim().slice(0, 60) || undefined : undefined,
    options: element.tagName === "SELECT" ? { count: element.options.length, sample: [...element.options].slice(0, 4).map((o) => [o.value, o.text.trim()]) } : undefined,
  }
}

async function inspect() {
  const snapshot = {
    url: location.pathname,
    title: document.title,
    forms: [...document.forms].map((form) => ({ id: form.id, action: form.getAttribute("action") })),
    controls: [...document.querySelectorAll("select, input:not([type=hidden]), button, a[href^='javascript:']")].map(describe),
    tables: [...document.querySelectorAll("table")].map((table) => ({
      id: table.id || undefined,
      rows: table.rows.length,
      header: [...(table.rows[0]?.cells || [])].map((cell) => cell.textContent.trim().slice(0, 40)),
    })),
  }
  const text = JSON.stringify(snapshot, null, 2)
  await navigator.clipboard.writeText(text)
  log(`Copied the page layout (${snapshot.controls.length} controls, ${snapshot.tables.length} tables). Paste it to Claude.`)
}

shadow.addEventListener("click", (event) => {
  const action = event.target.closest("button")?.dataset.action
  if (action === "collapse") $(".panel").classList.toggle("collapsed")
  if (action === "compare") compare()
  if (action === "fill-next") fillNext()
  if (action === "inspect") inspect().catch((error) => log(error.message, true))
})

chrome.storage.local.get("order").then((stored) => {
  order = stored.order || null
  refresh()
})

chrome.storage.onChanged.addListener((changes) => {
  if (!changes.order) return
  order = changes.order.newValue
  refresh()
})
