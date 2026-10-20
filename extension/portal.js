const key = (choice) => `${choice.instcd}|${choice.brcd}|${choice.quota}`.toLowerCase()
const label = (choice) => `${choice.institute} · ${choice.program} · ${choice.quota}`

const host = document.createElement("div")
host.id = "choice-planner-filler"
const shadow = host.attachShadow({ mode: "open" })
shadow.innerHTML = `
  <style>
    :host { all: initial; }
    .panel { position: fixed; right: 16px; bottom: 16px; z-index: 2147483647; width: 340px; max-height: 75vh; display: flex; flex-direction: column; gap: 10px; padding: 14px; border-radius: 16px; background: #101423; color: #fff; font: 500 13px/1.4 system-ui, sans-serif; box-shadow: 0 12px 32px rgba(0,0,0,.35); }
    .panel.collapsed .body { display: none; }
    header { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
    strong { font-size: 14px; }
    button { font: inherit; border: 1px solid #3a3d78; background: transparent; color: #fff; border-radius: 10px; padding: 6px 10px; cursor: pointer; }
    button:hover:not(:disabled) { background: #3d3bf3; border-color: #3d3bf3; }
    button:disabled { opacity: .45; cursor: default; }
    .body { display: flex; flex-direction: column; gap: 10px; min-height: 0; }
    .actions { display: flex; flex-wrap: wrap; gap: 6px; }
    .muted { color: #aab0c6; margin: 0; }
    .diff { overflow: auto; max-height: 40vh; display: flex; flex-direction: column; gap: 10px; }
    .diff:empty { display: none; }
    .diff h3 { margin: 0 0 4px; font-size: 12px; text-transform: uppercase; letter-spacing: .04em; }
    .diff ul { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 3px; }
    .diff li { display: flex; gap: 8px; }
    .diff .rank { flex: none; min-width: 34px; color: #aab0c6; font-variant-numeric: tabular-nums; }
    .missing h3 { color: #ffd27a; }
    .extra h3 { color: #ff9a9a; }
    .moved h3 { color: #9ec5ff; }
    .synced { color: #7ee2a8; font-weight: 600; margin: 0; }
    .log { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 4px; }
    .log:empty { display: none; }
    .log li.error { color: #ff9a9a; }
  </style>
  <section class="panel">
    <header><strong>Choice Planner filler</strong><button type="button" data-action="collapse" aria-label="Collapse">–</button></header>
    <div class="body">
      <p class="muted" data-summary>Loading your order…</p>
      <div class="diff" data-diff></div>
      <div class="actions">
        <button type="button" data-action="fill-next">Add next missing</button>
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
  while ($("[data-log]").children.length > 3) $("[data-log]").lastElementChild.remove()
}

function mapped() {
  return PortalAdapter.ready && PortalAdapter.isChoicePage()
}

function diff() {
  const filled = PortalAdapter.readFilled()
  const filledKeys = new Set(filled.map(key))
  const wantedKeys = new Set(order.choices.map(key))
  const missing = order.choices.filter((choice) => !filledKeys.has(key(choice)))
  const extra = filled.map((choice, index) => ({ ...choice, rank: index + 1 })).filter((choice) => !wantedKeys.has(key(choice)))
  const planned = order.choices.filter((choice) => filledKeys.has(key(choice)))
  const actual = filled.map((choice, index) => ({ ...choice, rank: index + 1 })).filter((choice) => wantedKeys.has(key(choice)))
  const moved = actual.filter((choice, index) => key(choice) !== key(planned[index]))
    .map((choice) => ({ ...choice, wantedRank: order.choices.find((wanted) => key(wanted) === key(choice)).rank }))
  return { missing, extra, moved }
}

function section(className, title, items, rank) {
  const wrap = document.createElement("div")
  wrap.className = className
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
  wrap.append(heading, list)
  return wrap
}

function renderDiff() {
  const box = $("[data-diff]")
  const fillNextButton = $('[data-action="fill-next"]')
  box.replaceChildren()
  fillNextButton.disabled = true
  if (!order || !mapped()) return

  const { missing, extra, moved } = diff()
  if (missing.length) box.append(section("missing", "Missing on the portal", missing, (c) => `#${c.rank}`))
  if (extra.length) box.append(section("extra", "On the portal, not in your order", extra, (c) => `P${c.rank}`))
  if (moved.length) box.append(section("moved", "Different position", moved, (c) => `P${c.rank}→#${c.wantedRank}`))
  if (!box.children.length) {
    const synced = document.createElement("p")
    synced.className = "synced"
    synced.textContent = "In sync: the portal matches your order."
    box.append(synced)
  }
  fillNextButton.disabled = missing.length === 0
}

function refresh() {
  $("[data-summary]").textContent = !order
    ? "No order yet. Open Choice Planner in this browser and it syncs here."
    : `${order.choices.length} choices from Choice Planner${order.owner ? ` (${order.owner})` : ""}, synced ${new Date(order.sentAt).toLocaleString()}.${mapped() ? "" : " Open Choice Filling to see the differences."}`
  renderDiff()
}

async function fillNext() {
  const next = diff().missing[0]
  if (!next) return
  try {
    await PortalAdapter.add(next)
    log(`Added #${next.rank} ${next.institute}. It is not saved until you press Save and Continue.`)
  } catch (error) {
    log(error.message, true)
  }
  renderDiff()
}


shadow.addEventListener("click", (event) => {
  const action = event.target.closest("button")?.dataset.action
  if (action === "collapse") $(".panel").classList.toggle("collapsed")
  if (action === "fill-next") fillNext()
})

let renderTimer
new MutationObserver(() => {
  clearTimeout(renderTimer)
  renderTimer = setTimeout(renderDiff, 150)
}).observe(document.body, { childList: true, subtree: true })

chrome.storage.local.get("order").then((stored) => {
  order = stored.order || null
  refresh()
})

chrome.storage.onChanged.addListener((changes) => {
  if (!changes.order) return
  order = changes.order.newValue
  refresh()
})
