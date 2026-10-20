import "sortablejs"

const PAGE_SIZE = 150
const SAVE_DELAY = 600
const RETRY_DELAY = 5000
const COURSE_ORDER = ["MD", "MS", "DNB", "DNB 6-yr", "DNB Diploma", "Diploma"]
const COURSE_BADGES = {
  MD: { text: "MD", kind: "md" },
  MS: { text: "MS", kind: "ms" },
  DNB: { text: "DNB", kind: "dnb" },
  "DNB 6-yr": { text: "DNB 6y", kind: "dnb6" },
  "DNB Diploma": { text: "DNB Dip", kind: "dnbdip" },
  Diploma: { text: "Dip", kind: "dip" },
}
const STATE_BADGES = {
  "Andhra Pradesh": { text: "AP", kind: "region-south" },
  "Karnataka": { text: "KA", kind: "region-south" },
  "Kerala": { text: "KL", kind: "region-south" },
  "Tamil Nadu": { text: "TN", kind: "region-south" },
  "Telangana": { text: "TG", kind: "region-south" },
  "Puducherry": { text: "PY", kind: "region-south" },
  "Lakshadweep": { text: "LD", kind: "region-south" },
  "Andaman and Nicobar Islands": { text: "AN", kind: "region-south" },
  "Gujarat": { text: "GJ", kind: "region-west" },
  "Maharashtra": { text: "MH", kind: "region-west" },
  "Goa": { text: "GA", kind: "region-west" },
  "Rajasthan": { text: "RJ", kind: "region-west" },
  "Dadra and Nagar Haveli": { text: "DN", kind: "region-west" },
  "Daman and Diu": { text: "DD", kind: "region-west" },
  "Delhi": { text: "DL", kind: "region-north" },
  "Haryana": { text: "HR", kind: "region-north" },
  "Punjab": { text: "PB", kind: "region-north" },
  "Himachal Pradesh": { text: "HP", kind: "region-north" },
  "Jammu and Kashmir": { text: "JK", kind: "region-north" },
  "Ladakh": { text: "LA", kind: "region-north" },
  "Chandigarh": { text: "CH", kind: "region-north" },
  "Uttarakhand": { text: "UK", kind: "region-north" },
  "Uttar Pradesh": { text: "UP", kind: "region-north" },
  "Madhya Pradesh": { text: "MP", kind: "region-central" },
  "Chhattisgarh": { text: "CG", kind: "region-central" },
  "Bihar": { text: "BR", kind: "region-east" },
  "Jharkhand": { text: "JH", kind: "region-east" },
  "Odisha": { text: "OD", kind: "region-east" },
  "West Bengal": { text: "WB", kind: "region-east" },
  "Assam": { text: "AS", kind: "region-northeast" },
  "Arunachal Pradesh": { text: "AR", kind: "region-northeast" },
  "Manipur": { text: "MN", kind: "region-northeast" },
  "Meghalaya": { text: "ML", kind: "region-northeast" },
  "Mizoram": { text: "MZ", kind: "region-northeast" },
  "Nagaland": { text: "NL", kind: "region-northeast" },
  "Sikkim": { text: "SK", kind: "region-northeast" },
  "Tripura": { text: "TR", kind: "region-northeast" },
}
const TYPE_SHORT = { AIC: "Govt", CUN: "Central University", DUN: "Deemed University", DNB: "DNB Govt", DNP: "DNB Private" }
const DOUBTFUL_HINT = "State guessed from the address and may be wrong. Check the address."

const FACET_NAMES = ["speciality", "course", "state", "type", "quota"]

const $ = (sel) => document.querySelector(sel)
const make = (tag, props = {}) => Object.assign(document.createElement(tag), props)

function iconSvg(spriteUrl, name, className = "icon") {
  const ns = "http://www.w3.org/2000/svg"
  const svg = document.createElementNS(ns, "svg")
  svg.setAttribute("class", className)
  svg.setAttribute("aria-hidden", "true")
  const use = document.createElementNS(ns, "use")
  use.setAttribute("href", `${spriteUrl}#${name}`)
  svg.append(use)
  return svg
}

function badgeEl(badge) {
  return make("span", { className: `badge badge-${badge.kind}`, textContent: badge.text })
}
const root = document.getElementById("planner")

const config = root && {
  counselling: root.dataset.counselling,
  catalogUrl: root.dataset.catalogUrl,
  spriteUrl: root.dataset.iconsUrl,
  listUrl: root.dataset.listUrl,
  snapshotsUrl: root.dataset.snapshotsUrl,
  owner: root.dataset.owner,
  ownList: root.dataset.ownList === "true",
}

const state = {
  choices: [],
  byId: new Map(),
  picks: [],
  pickIndex: new Map(),
  filtered: [],
  shown: PAGE_SIZE,
  revision: null,
  dirty: false,
  saving: false,
  conflict: false,
  saveTimer: null,
  reviewOpen: null,
  facets: [],
  selected: Object.fromEntries(FACET_NAMES.map((n) => [n, new Set()])),
  openPick: null,
  groupBy: "none",
  orderView: "ranked",
  expanded: new Set(),
}

const storage = {
  get(key) {
    try {
      return JSON.parse(localStorage.getItem(key) || "null")
    } catch {
      return null
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value))
      return true
    } catch {
      return false
    }
  },
  remove(key) {
    try {
      localStorage.removeItem(key)
    } catch {}
  },
}

const deviceKey = () => `planner:${config.counselling}:device`
const accountKey = () => `planner:${config.counselling}:account:${config.owner}`
const synced = () => Boolean(config.listUrl)

function csrfToken() {
  return document.querySelector("meta[name=csrf-token]")?.content
}

async function api(url, options = {}) {
  const res = await fetch(url, {
    ...options,
    headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrfToken() },
    credentials: "same-origin",
  })
  if (!res.ok) {
    const err = new Error((await res.json().catch(() => ({}))).error || res.statusText || "network error")
    err.status = res.status
    throw err
  }
  return res.json()
}

function normalize(text) {
  return (text || "").toLowerCase().normalize("NFKD").replace(/[^a-z0-9 ]+/g, " ").replace(/\s+/g, " ").trim()
}

function buildCatalog(data) {
  const institutes = new Map(
    data.institutes.map(([code, name, address, typeCode, stateName, doubtful, short]) => [
      code,
      { code, name, short: short || name, address, typeCode, typeName: data.institute_types[typeCode] || typeCode, state: stateName || "", doubtful: doubtful === 1 },
    ]),
  )
  state.choices = data.choices.map(([id, instcd, brcd, quota]) => {
    const inst = institutes.get(instcd)
    const [program, course, speciality, icon] = data.programs[brcd] || [brcd, "Other", brcd, "stethoscope"]
    return {
      id,
      inst,
      brcd,
      program,
      course,
      speciality,
      icon,
      quota,
      haystack: normalize(`${inst.name} ${inst.address} ${inst.state} ${speciality} ${course} ${program} ${quota} ${inst.typeName}`),
    }
  })
  state.byId = new Map(state.choices.map((c) => [c.id, c]))
  state.contacts = data.contacts || {}

  const specialityIcons = new Map(state.choices.map((c) => [c.speciality, c.icon]))
  const courses = new Set(state.choices.map((c) => c.course))
  const typeNames = data.institute_types
  state.facets = [
    { name: "speciality", title: "Speciality", mode: "list", searchable: true, values: uniqueSorted(state.choices.map((c) => c.speciality)), key: (c) => c.speciality, icon: (v) => specialityIcons.get(v) },
    { name: "course", title: "Course", mode: "chips", values: [...COURSE_ORDER.filter((c) => courses.has(c)), ...[...courses].filter((c) => !COURSE_ORDER.includes(c))], key: (c) => c.course, badge: (v) => courseBadge(v), short: true },
    { name: "state", title: "State", mode: "list", searchable: true, values: uniqueSorted(state.choices.map((c) => c.inst.state).filter(Boolean)), key: (c) => c.inst.state, badge: (v) => stateBadge(v) },
    { name: "type", title: "Institute type", mode: "chips", values: Object.keys(typeNames), key: (c) => c.inst.typeCode, label: (v) => TYPE_SHORT[v] || typeNames[v] || v },
    { name: "quota", title: "Quota", mode: "chips", values: uniqueSorted(state.choices.map((c) => c.quota)), key: (c) => c.quota },
  ]
  restoreFilters()
}

function courseBadge(course) {
  return COURSE_BADGES[course] || { text: course, kind: "other" }
}

function programNodes(c, extra = "") {
  return [iconSvg(config.spriteUrl, c.icon, "icon icon-spec"), document.createTextNode(c.speciality), badgeEl(courseBadge(c.course)), ...(extra ? [document.createTextNode(extra)] : [])]
}

function stateBadge(name) {
  return STATE_BADGES[name] || { text: "?", kind: "other" }
}

function stateNodes(inst) {
  if (!inst.state) return [document.createTextNode("State unknown")]
  return [badgeEl(stateBadge(inst.state)), document.createTextNode(inst.doubtful ? `${inst.state} (?)` : inst.state)]
}

function uniqueSorted(values) {
  return [...new Set(values)].sort((a, b) => a.localeCompare(b))
}

function facetCounts(skip, key) {
  const f = filters()
  f[skip] = new Set()
  const counts = new Map()
  for (const c of state.choices) {
    if (!matches(c, f)) continue
    const k = key(c)
    counts.set(k, (counts.get(k) || 0) + 1)
  }
  return counts
}

function matches(c, f) {
  return (
    (!f.speciality.size || f.speciality.has(c.speciality)) &&
    (!f.course.size || f.course.has(c.course)) &&
    (!f.state.size || f.state.has(c.inst.state)) &&
    (!f.type.size || f.type.has(c.inst.typeCode)) &&
    (!f.quota.size || f.quota.has(c.quota)) &&
    (!f.hide || !state.pickIndex.has(c.id)) &&
    f.terms.every((t) => c.haystack.includes(t))
  )
}

function cleanPicks(picks) {
  const seen = new Set()
  return (picks || [])
    .filter((p) => state.byId.has(p.choice_id) && !seen.has(p.choice_id) && seen.add(p.choice_id))
    .map((p) => ({ choice_id: p.choice_id, note: p.note || "" }))
}

function samePicks(a, b) {
  return a.length === b.length && a.every((p, i) => p.choice_id === b[i].choice_id && (p.note || "").trim() === (b[i].note || "").trim())
}

function setPicks(picks) {
  state.picks = cleanPicks(picks)
  reindex()
}

function reindex() {
  state.pickIndex = new Map(state.picks.map((p, i) => [p.choice_id, i]))
  $("#tab-count").textContent = state.picks.length
  $("#order-count").textContent = `${state.picks.length} ${state.picks.length === 1 ? "choice" : "choices"}`
  syncFiller()
}

function filters() {
  return {
    terms: normalize($("#q").value).split(" ").filter(Boolean),
    ...Object.fromEntries(FACET_NAMES.map((n) => [n, new Set(state.selected[n])])),
    hide: $("#f-hide").checked,
  }
}

function applyFilters(resetPaging = true) {
  const f = filters()
  state.filtered = state.choices.filter((c) => matches(c, f))
  if (resetPaging) state.shown = PAGE_SIZE
  renderResults()
  refreshFilterUI()
}

const GROUP_PAGE = 30
const GROUP_PREVIEW = 3

function resultItem(c) {
  const li = $("#result-tpl").content.firstElementChild.cloneNode(true)
  li.dataset.id = c.id
  li.querySelector(".r-inst").textContent = c.inst.short
  const addr = li.querySelector(".r-addr")
  addr.textContent = c.inst.short === c.inst.name ? "" : c.inst.name
  addr.title = c.inst.name
  const meta = li.querySelector(".r-meta")
  meta.replaceChildren(...stateNodes(c.inst), document.createTextNode(` · ${c.quota} · ${TYPE_SHORT[c.inst.typeCode] || c.inst.typeName}`))
  meta.title = c.inst.doubtful ? DOUBTFUL_HINT : c.inst.typeName
  if (c.inst.doubtful) meta.title = DOUBTFUL_HINT
  const prog = li.querySelector(".r-prog")
  prog.replaceChildren(...programNodes(c))
  prog.title = c.program
  li.querySelector(".contact-btn").hidden = !state.contacts[c.inst.code]
  paintResult(li, c.id)
  return li
}

function groupRow(c, mode) {
  const li = make("li", { className: "g-row" })
  li.dataset.id = c.id
  const main = make("div", { className: "g-main" })
  if (mode === "institute") {
    const title = make("div", { className: "g-row-title" })
    title.append(...programNodes(c))
    title.title = c.program
    main.append(title, make("div", { className: "g-row-meta", textContent: c.quota }))
  } else {
    const meta = make("div", { className: "g-row-meta" })
    meta.append(badgeEl(courseBadge(c.course)), ...stateNodes(c.inst), document.createTextNode(` · ${c.quota} · ${TYPE_SHORT[c.inst.typeCode] || c.inst.typeName}`))
    main.append(make("div", { className: "g-row-title", textContent: c.inst.short, title: c.inst.name }), meta)
  }
  li.append(main)
  if (mode === "speciality" && state.contacts[c.inst.code]) {
    const contact = make("button", { type: "button", className: "contact-btn icon-only" })
    contact.setAttribute("aria-label", "DNB contact")
    contact.append(iconSvg(config.spriteUrl, "contact"))
    li.append(contact)
  }
  li.append(make("button", { type: "button", className: "r-add" }))
  paintResult(li, c.id)
  return li
}

function groupsOf(choices) {
  const key = state.groupBy === "institute" ? (c) => c.inst.code : (c) => c.speciality
  const groups = new Map()
  for (const c of choices) {
    const k = key(c)
    if (!groups.has(k)) groups.set(k, [])
    groups.get(k).push(c)
  }
  const label = (items) => (state.groupBy === "institute" ? items[0].inst.short : items[0].speciality)
  return [...groups.entries()].map(([k, items]) => ({ key: k, items, label: label(items) })).sort((a, b) => a.label.localeCompare(b.label))
}

function groupCard(group) {
  const mode = state.groupBy
  const first = group.items[0]
  const li = make("li", { className: "group" })
  li.dataset.group = group.key
  const head = make("div", { className: "g-head" })
  if (mode === "speciality") head.append(make("span", { className: "g-icon" }))
  if (mode === "speciality") head.firstChild.append(iconSvg(config.spriteUrl, first.icon, "icon icon-spec"))
  const text = make("div", { className: "g-text" })
  const picked = group.items.filter((c) => state.pickIndex.has(c.id)).length
  const count = `${group.items.length} ${mode === "institute" ? (group.items.length === 1 ? "program" : "programs") : group.items.length === 1 ? "institute" : "institutes"}${picked ? ` · ${picked} in your order` : ""}`
  text.append(make("span", { className: "g-title", textContent: group.label, title: mode === "institute" ? first.inst.name : "" }))
  if (mode === "institute") {
    const meta = make("span", { className: "g-meta" })
    meta.append(...stateNodes(first.inst), document.createTextNode(` · ${TYPE_SHORT[first.inst.typeCode] || first.inst.typeName} · ${count}`))
    text.append(meta)
    if (first.inst.short !== first.inst.name) text.append(make("span", { className: "r-addr", textContent: first.inst.name }))
  } else {
    text.append(make("span", { className: "g-meta", textContent: count }))
  }
  head.append(text)
  if (mode === "institute" && state.contacts[first.inst.code]) {
    const contact = make("button", { type: "button", className: "contact-btn" })
    contact.dataset.code = first.inst.code
    contact.append(iconSvg(config.spriteUrl, "contact"), document.createTextNode("DNB contact"))
    text.append(contact)
  }
  li.append(head)
  const rows = make("ul", { className: "g-rows" })
  const open = state.expanded.has(group.key)
  const visible = open ? group.items : group.items.slice(0, GROUP_PREVIEW)
  for (const c of visible) rows.append(groupRow(c, mode))
  li.append(rows)
  const hidden = group.items.length - visible.length
  const addable = group.items.filter((c) => !state.pickIndex.has(c.id)).length
  if (hidden > 0 || addable > 1) {
    const foot = make("div", { className: "g-foot" })
    if (hidden > 0) foot.append(make("button", { type: "button", className: "button-link g-more", textContent: `Show ${hidden} more` }))
    else if (open && group.items.length > GROUP_PREVIEW) foot.append(make("button", { type: "button", className: "button-link g-more", textContent: "Show fewer" }))
    if (addable > 1) foot.append(make("button", { type: "button", className: "button-link g-addall", textContent: `Add all ${addable}` }))
    li.append(foot)
  }
  return li
}

function renderResults() {
  const frag = document.createDocumentFragment()
  const grouped = state.groupBy !== "none"
  const groups = grouped ? groupsOf(state.filtered) : null
  if (grouped) for (const group of groups.slice(0, Math.ceil(state.shown / PAGE_SIZE) * GROUP_PAGE)) frag.append(groupCard(group))
  else for (const c of state.filtered.slice(0, state.shown)) frag.append(resultItem(c))
  $("#results").classList.toggle("grouped", grouped)
  $("#results").replaceChildren(frag)
  $("#results").removeAttribute("aria-busy")

  const total = state.filtered.length
  $("#result-count").textContent = grouped
    ? `${groups.length.toLocaleString()} ${state.groupBy === "institute" ? "institutes" : "specialities"} · ${total.toLocaleString()} choices`
    : `${total.toLocaleString()} of ${state.choices.length.toLocaleString()} choices`
  $("#more").hidden = grouped ? Math.ceil(state.shown / PAGE_SIZE) * GROUP_PAGE >= groups.length : state.shown >= total
  const addable = state.filtered.filter((c) => !state.pickIndex.has(c.id)).length
  const addAll = $("#add-all")
  addAll.hidden = addable === 0 || addable === state.choices.length
  addAll.textContent = `Add all ${addable.toLocaleString()}`
}

function paintResult(li, id) {
  const at = state.pickIndex.get(id)
  const btn = li.querySelector(".r-add")
  li.classList.toggle("added", at !== undefined)
  btn.textContent = at === undefined ? "+" : `#${at + 1}`
  btn.setAttribute("aria-label", at === undefined ? "Add to end of my order" : `In my order at number ${at + 1}, show it`)
}

function repaintVisibleResults() {
  if (state.groupBy !== "none") {
    renderResults()
    return
  }
  for (const li of $("#results").children) paintResult(li, Number(li.dataset.id))
}

function renderPicks() {
  const tpl = $("#pick-tpl")
  const frag = document.createDocumentFragment()
  state.picks.forEach((p, i) => {
    const c = state.byId.get(p.choice_id)
    const li = tpl.content.firstElementChild.cloneNode(true)
    li.dataset.id = c.id
    li.classList.toggle("open", state.openPick === c.id)
    li.querySelector(".p-rank").textContent = i + 1
    li.querySelector(".p-pos").value = i + 1
    li.querySelector(".p-note-preview").textContent = p.note
    li.querySelector(".p-inst").textContent = c.inst.short
    li.querySelector(".p-addr").textContent = c.inst.short === c.inst.name ? "" : c.inst.name
    const meta = li.querySelector(".p-meta")
    meta.replaceChildren(...programNodes(c), ...stateNodes(c.inst), document.createTextNode(` · ${c.quota}`))
    if (c.inst.doubtful) meta.title = DOUBTFUL_HINT
    li.querySelector(".p-note").value = p.note
    li.querySelector(".contact-btn").hidden = !state.contacts[c.inst.code]
    const prev = state.picks[i - 1] && state.byId.get(state.picks[i - 1].choice_id)
    const next = state.picks[i + 1] && state.byId.get(state.picks[i + 1].choice_id)
    const joinsPrev = prev?.inst.code === c.inst.code
    const joinsNext = next?.inst.code === c.inst.code
    li.classList.toggle("run-cont", joinsPrev)
    li.classList.toggle("run-open", joinsNext)
    if (!joinsNext) paintAlso(li, i, c)
    frag.append(li)
  })
  $("#picks").replaceChildren(frag)
  if (state.orderView !== "ranked") renderReview()
  $("#picks").removeAttribute("aria-busy")
  $("#empty").hidden = state.picks.length > 0
  filterPicks()
}

function runStart(i) {
  const code = state.byId.get(state.picks[i].choice_id).inst.code
  while (i > 0 && state.byId.get(state.picks[i - 1].choice_id).inst.code === code) i--
  return i
}

function paintAlso(li, end, c) {
  const start = runStart(end)
  const elsewhere = state.picks
    .map((p, i) => ({ p, i, c: state.byId.get(p.choice_id) }))
    .filter((x) => x.c.inst.code === c.inst.code && (x.i < start || x.i > end))
  const box = li.querySelector(".p-also")
  box.hidden = elsewhere.length === 0
  if (!elsewhere.length) return
  const list = elsewhere.slice(0, 3).map((x) => `${x.c.speciality} at #${x.i + 1}`).join(", ")
  li.querySelector(".p-also-text").textContent = `Also in your order: ${list}${elsewhere.length > 3 ? ` +${elsewhere.length - 3}` : ""}`
  li.querySelector(".p-gather").textContent = elsewhere[0].i < start ? "Move up next to them" : "Bring here"
}

function gatherInstitute(index) {
  const code = state.byId.get(state.picks[index].choice_id).inst.code
  const anchorIndex = state.picks.findIndex((p) => state.byId.get(p.choice_id).inst.code === code)
  const start = runStart(anchorIndex)
  let end = anchorIndex
  while (end + 1 < state.picks.length && state.byId.get(state.picks[end + 1].choice_id).inst.code === code) end++
  const run = state.picks.slice(start, end + 1)
  const others = state.picks.filter((p, i) => (i < start || i > end) && state.byId.get(p.choice_id).inst.code === code)
  const rest = state.picks.filter((p) => !run.includes(p) && !others.includes(p))
  const before = rest.filter((p) => state.picks.indexOf(p) < start)
  const after = rest.filter((p) => state.picks.indexOf(p) > end)
  state.picks = [...before, ...run, ...others, ...after]
  changed()
  flash(run[0].choice_id)
}

function renderReview() {
  const byInstitute = state.orderView === "institute"
  const groups = new Map()
  state.picks.forEach((p, i) => {
    const c = state.byId.get(p.choice_id)
    const key = byInstitute ? c.inst.code : c.speciality
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key).push({ c, rank: i + 1 })
  })
  const frag = document.createDocumentFragment()
  for (const [key, items] of groups) {
    const first = items[0].c
    const li = make("li", { className: "group" })
    li.dataset.group = key
    const head = make("div", { className: "g-head" })
    if (!byInstitute) {
      const iconBox = make("span", { className: "g-icon" })
      iconBox.append(iconSvg(config.spriteUrl, first.icon, "icon icon-spec"))
      head.append(iconBox)
    }
    const text = make("div", { className: "g-text" })
    const contiguous = items.every((x, j) => j === 0 || x.rank === items[j - 1].rank + 1)
    const meta = make("span", { className: "g-meta" })
    if (byInstitute) meta.append(...stateNodes(first.inst), document.createTextNode(" · "))
    meta.append(document.createTextNode(`${items.length} ${items.length === 1 ? "pick" : "picks"}${byInstitute && items.length > 1 && !contiguous ? ", not next to each other" : ""}`))
    text.append(make("span", { className: "g-title", textContent: byInstitute ? first.inst.short : first.speciality }), meta)
    head.append(text, make("span", { className: "best-rank", textContent: `best #${items[0].rank}` }))
    li.append(head)
    const rows = make("ul", { className: "g-rows" })
    for (const { c, rank } of items) {
      const row = make("li", { className: "g-row" })
      row.dataset.id = c.id
      const main = make("div", { className: "g-main" })
      const title = make("div", { className: "g-row-title" })
      if (byInstitute) title.append(...programNodes(c))
      else {
        title.classList.add("one-line")
        title.append(make("span", { className: "g-name", textContent: c.inst.short, title: c.inst.name }), badgeEl(courseBadge(c.course)))
      }
      main.append(title)
row.append(make("span", { className: "rank-chip", textContent: `#${rank}` }), main)
if (state.reviewOpen === c.id) {
  row.classList.add("open")
  const note = state.picks[rank - 1].note
  const tools = make("div", { className: "r-tools" })
  if (note) tools.append(make("p", { className: "p-note-preview", textContent: note }))
  const ctl = make("div", { className: "p-ctl" })
  const pos = make("label", { className: "p-pos-label" })
  const input = make("input", { type: "number", min: 1, value: rank, className: "review-pos", inputMode: "numeric" })
  input.setAttribute("aria-label", "Move to position")
  pos.append(make("span", { textContent: "Move to" }), input)
  const remove = make("button", { type: "button", className: "icon-btn danger review-remove" })
  remove.setAttribute("aria-label", "Remove")
  remove.append(iconSvg(config.spriteUrl, "trash-2"))
  ctl.append(pos, remove)
  tools.append(ctl, make("button", { type: "button", className: "button-link review-show", textContent: "Show in ranked list" }))
  main.append(tools)
}
      rows.append(row)
    }
    li.append(rows)
    if (byInstitute && items.length > 1 && !contiguous) {
      const foot = make("div", { className: "g-foot" })
      const btn = make("button", { type: "button", className: "button-link g-together", textContent: "Keep these together in the ranking" })
      btn.dataset.rank = items[0].rank
      foot.append(btn)
      li.append(foot)
    }
    frag.append(li)
  }
  $("#picks-review").replaceChildren(frag)
}

function setOrderView(view) {
  state.orderView = view
  try {
    localStorage.setItem(`planner:${config.counselling}:order-view`, view)
  } catch {}
  for (const btn of document.querySelectorAll("#order-view button")) btn.setAttribute("aria-checked", String(btn.dataset.view === view))
  const ranked = view === "ranked"
  $("#picks").hidden = !ranked
  $("#picks-review").hidden = ranked
  $("#order-q").closest("label").hidden = !ranked
  if (!ranked) renderReview()
}

function filterPicks() {
  const terms = normalize($("#order-q").value).split(" ").filter(Boolean)
  for (const li of $("#picks").children) {
    const c = state.byId.get(Number(li.dataset.id))
    li.classList.toggle("dim", terms.length > 0 && !terms.every((t) => c.haystack.includes(t)))
  }
}

function rerender() {
  reindex()
  renderPicks()
  applyFilters(false)
}

function changed() {
  if (state.importJustApplied) state.importJustApplied = false
  else if (state.importUndo) closeMccImport()
  reindex()
  renderPicks()
  if ($("#f-hide").checked) applyFilters(false)
  else repaintVisibleResults()
  scheduleSave()
}

function addChoices(ids) {
  const fresh = ids.filter((id) => !state.pickIndex.has(id))
  if (!fresh.length) return
  state.picks.push(...fresh.map((id) => ({ choice_id: id, note: "" })))
  changed()
}

function move(from, to) {
  to = Math.max(0, Math.min(state.picks.length - 1, to))
  if (from === to) return
  const [item] = state.picks.splice(from, 1)
  state.picks.splice(to, 0, item)
  changed()
  flash(item.choice_id)
}

function flash(id) {
  const li = $(`#picks li[data-id="${id}"]`)
  if (!li) return
  li.scrollIntoView({ block: "nearest" })
  li.classList.add("flash")
  setTimeout(() => li.classList.remove("flash"), 1000)
}

function setStatus(text, error = false) {
  const el = $("#save-status")
  el.textContent = text
  el.style.color = error ? "var(--danger)" : ""
  root.classList.toggle("busy", /…$/.test(text))
  root.classList.toggle("sync-error", error)
}

function timeNow() {
  return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
}

function writeCache() {
  if (state.conflict) return true
  const ok = synced()
    ? storage.set(accountKey(), { revision: state.revision, dirty: state.dirty, picks: state.picks })
    : storage.set(deviceKey(), { picks: state.picks, savedAt: new Date().toISOString() })
  if (!ok) setStatus("This browser is blocking local storage, so changes can't be kept on this device.", true)
  return ok
}

function scheduleSave() {
  state.dirty = true
  writeCache()
  if (!synced()) {
    state.saveLabel = null
    setStatus(`Saved on this device ${timeNow()}`)
    return
  }
  if (state.conflict) return
  setStatus("Unsaved…")
  clearTimeout(state.saveTimer)
  state.saveTimer = setTimeout(save, SAVE_DELAY)
}

async function save() {
  if (!synced() || state.conflict) return
  if (state.saving) {
    state.saveTimer = setTimeout(save, SAVE_DELAY)
    return
  }
  if (!navigator.onLine) {
    setStatus("Offline — saved on this device, will sync when back online")
    return
  }
  state.saving = true
  state.dirty = false
  setStatus("Saving…")
  try {
    const label = state.saveLabel
    state.saveLabel = null
    const saved = await api(config.listUrl, { method: "PUT", body: JSON.stringify({ base: state.revision, picks: state.picks, label }) }).catch((error) => {
      state.saveLabel ||= label
      throw error
    })
    state.revision = saved.revision
    writeCache()
    setStatus(state.dirty ? "Unsaved…" : `Synced ${timeNow()}`)
  } catch (err) {
    state.dirty = true
    writeCache()
    await handleSaveError(err)
  } finally {
    state.saving = false
  }
}

async function handleSaveError(err) {
  if (err.status === 409) {
    const server = await api(config.listUrl).catch(() => null)
    if (server && samePicks(server.picks, state.picks)) {
      state.revision = server.revision
      state.dirty = false
      writeCache()
      setStatus(`Synced ${timeNow()}`)
    } else if (server) {
      offerChoice(server, "Your order was changed on another device while this one had unsynced edits.")
    } else {
      setStatus("Changed on another device. Reload to resolve.", true)
      state.conflict = true
    }
  } else if (err.status === 401) {
    setStatus("Signed out — changes are kept on this device. Sign in again to sync.", true)
  } else if (err.status >= 400 && err.status < 500) {
    setStatus(`Sync rejected: ${err.message}. Reload the page.`, true)
  } else {
    setStatus("Couldn't reach the server — saved on this device, retrying", true)
    state.saveTimer = setTimeout(save, RETRY_DELAY)
  }
}

function offerChoice(server, message, { deviceLabel = "Keep this device's order", accountLabel = "Use my account's order", devicePicks = state.picks, onDone } = {}) {
  state.conflict = true
  clearTimeout(state.saveTimer)
  const box = $("#adopt")
  $("#adopt-text").textContent = `${message} This device: ${devicePicks.length} choices. Account: ${server.picks.length} choices.`
  $("#adopt-device").textContent = deviceLabel
  $("#adopt-account").textContent = accountLabel
  box.hidden = false
  setStatus("Choose which order to keep", true)

  const finish = () => {
    box.hidden = true
    state.conflict = false
    onDone?.()
  }
  $("#adopt-device").onclick = () => {
    state.picks = cleanPicks(devicePicks)
    state.revision = server.revision
    finish()
    rerender()
    scheduleSave()
  }
  $("#adopt-account").onclick = () => {
    state.revision = server.revision
    state.dirty = false
    setPicks(server.picks)
    finish()
    writeCache()
    rerender()
    setStatus(`Synced ${timeNow()}`)
  }
}

async function loadSynced() {
  const cached = storage.get(accountKey())
  const device = storage.get(deviceKey())
  let server
  try {
    server = await api(config.listUrl)
  } catch {
    server = null
  }

  if (!server) {
    state.revision = cached?.revision ?? null
    state.dirty = Boolean(cached?.dirty)
    setPicks(cached?.picks || [])
    setStatus(cached ? "Offline — showing the copy saved on this device" : "Offline and nothing saved on this device yet", !cached)
    return
  }

  const devicePicks = config.ownList ? cleanPicks(device?.picks) : []
  const clearDevice = () => storage.remove(deviceKey())

  if (cached?.dirty && cached.revision === server.revision) {
    state.revision = server.revision
    setPicks(cached.picks)
    scheduleSave()
  } else if (cached?.dirty && !samePicks(cleanPicks(cached.picks), server.picks)) {
    state.revision = server.revision
    setPicks(server.picks)
    offerChoice(server, "This device has changes that never synced, and your account changed since.", { devicePicks: cleanPicks(cached.picks) })
  } else {
    state.revision = server.revision
    setPicks(server.picks)
    writeCache()
    setStatus("")
  }

  if (devicePicks.length && !state.conflict) {
    if (!server.picks.length) {
      state.picks = devicePicks
      clearDevice()
      rerender()
      scheduleSave()
    } else if (samePicks(devicePicks, server.picks)) {
      clearDevice()
    } else {
      offerChoice(server, "You made an order on this device before signing in, and your account already has one.", {
        deviceLabel: "Use the order from before I signed in",
        accountLabel: "Keep my account's order",
        devicePicks,
        onDone: clearDevice,
      })
    }
  }
}

function loadDevice() {
  const device = storage.get(deviceKey())
  setPicks(device?.picks || [])
  setStatus(device?.savedAt ? `Saved on this device ${new Date(device.savedAt).toLocaleString([], { dateStyle: "medium", timeStyle: "short" })}` : "")
}

function exportCsv() {
  const header = ["rank", "institute_code", "institute", "state", "state_doubtful", "institute_type", "speciality", "course", "program_code", "program", "quota", "note"]
  const rows = state.picks.map((p, i) => {
    const c = state.byId.get(p.choice_id)
    return [i + 1, c.inst.code, c.inst.name, c.inst.state, c.inst.doubtful ? "yes" : "", c.inst.typeName, c.speciality, c.course, c.brcd, c.program, c.quota, p.note]
  })
  const csv = [header, ...rows].map((r) => r.map((v) => `"${String(v ?? "").replace(/"/g, '""')}"`).join(",")).join("\r\n")
  const link = document.createElement("a")
  link.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }))
  link.download = `choices-${new Date().toISOString().slice(0, 16).replace(/[-:T]/g, "")}.csv`
  link.click()
  setTimeout(() => URL.revokeObjectURL(link.href), 1000)
}

function fillerPayload() {
  return JSON.stringify({
    counselling: config.counselling,
    owner: config.owner || null,
    sentAt: new Date().toISOString(),
    choices: state.picks.map((p, i) => {
      const c = state.byId.get(p.choice_id)
      return { rank: i + 1, instcd: c.inst.code, brcd: c.brcd, quota: c.quota, institute: c.inst.name, program: c.program }
    }),
  })
}


function syncFiller() {
  if (!document.documentElement.dataset.choiceFiller || !state.byId.size) return
  clearTimeout(state.fillerTimer)
  state.fillerTimer = setTimeout(() => document.dispatchEvent(new CustomEvent("choice-planner:order", { detail: fillerPayload() })), 300)
}

function fillerReady() {
  $("#get-filler").hidden = true
  syncFiller()
  document.dispatchEvent(new CustomEvent("choice-planner:listening"))
}

function choiceIdsByKey() {
  return new Map(state.choices.map((c) => [`${c.inst.code}|${c.brcd}|${c.quota}`.toLowerCase(), c.id]))
}

function offerMccImport(event) {
  const portal = JSON.parse(event.detail)
  const ids = choiceIdsByKey()
  const matched = portal.choices.map((c) => ids.get(`${c.instcd}|${c.brcd}|${c.quota}`.toLowerCase())).filter(Boolean)
  const unknown = portal.choices.length - matched.length
  const same = matched.length === state.picks.length && matched.every((id, i) => state.picks[i].choice_id === id)
  state.mccImport = matched
  $("#mcc-import-text").textContent = same
    ? `MCC's saved list matches your order (${matched.length} choices).`
    : `MCC has ${portal.choices.length} saved choices${unknown ? `, ${unknown} not in this catalog and left out` : ""}. Replace your order (${state.picks.length} choices) with MCC's?`
  $("#mcc-import-apply").hidden = same || state.conflict
  $("#mcc-import-close").textContent = same ? "Close" : "Not now"
  $("#mcc-import").hidden = false
}

function applyMccImport() {
  document.dispatchEvent(new CustomEvent("choice-planner:import-done"))
  const notes = new Map(state.picks.map((p) => [p.choice_id, p.note]))
  state.importUndo = state.picks.map((p) => ({ ...p }))
  state.picks = state.mccImport.map((id) => ({ choice_id: id, note: notes.get(id) || "" }))
  state.saveLabel = "Imported from MCC"
  state.importJustApplied = true
  changed()
  $("#mcc-import-text").textContent = `Imported ${state.picks.length} choices from MCC.`
  $("#mcc-import-apply").hidden = true
  $("#mcc-import-close").textContent = "Undo"
  $("#mcc-import-close").onclick = undoMccImport
}

function undoMccImport() {
  state.picks = state.importUndo
  state.saveLabel = "Before MCC import"
  changed()
  closeMccImport()
}

function closeMccImport() {
  document.dispatchEvent(new CustomEvent("choice-planner:import-done"))
  state.importUndo = null
  $("#mcc-import").hidden = true
  $("#mcc-import-close").onclick = closeMccImport
}

async function openHistory() {
  const drawer = $("#history")
  drawer.hidden = false
  const list = $("#snapshots")
  const note = (text) => list.replaceChildren(Object.assign(document.createElement("li"), { textContent: text }))
  note("Loading…")
  let snaps
  try {
    snaps = await api(config.snapshotsUrl)
  } catch (err) {
    note(`Could not load history: ${err.message}`)
    return
  }
  list.replaceChildren(...snaps.map((s) => snapshotRow(s, drawer)))
}

function snapshotRow(s, drawer) {
  const li = document.createElement("li")
  const info = document.createElement("div")
  const when = document.createElement("div")
  const meta = document.createElement("div")
  when.textContent = new Date(s.created_at).toLocaleString([], { dateStyle: "medium", timeStyle: "short" })
  meta.className = "muted"
  meta.textContent = `${s.count} choices${s.label ? ` · ${s.label}` : ""}`
  info.append(when, meta)
  const btn = document.createElement("button")
  btn.textContent = "Restore"
  btn.addEventListener("click", async () => {
    if (btn.dataset.armed !== "1") {
      btn.dataset.armed = "1"
      btn.textContent = "Confirm restore"
      return
    }
    if (state.saving) {
      setStatus("Still saving. Try restore again in a moment.")
      return
    }
    clearTimeout(state.saveTimer)
    try {
      const restored = await api(`${config.snapshotsUrl}/${s.id}/restore`, { method: "POST", body: "{}" })
      state.revision = restored.revision
      setPicks(restored.picks)
    } catch (err) {
      setStatus(`Restore failed: ${err.message}`, true)
      if (state.dirty) scheduleSave()
      return
    }
    state.dirty = false
    state.conflict = false
    $("#adopt").hidden = true
    writeCache()
    rerender()
    setStatus("Restored")
    drawer.hidden = true
  })
  li.append(info, btn)
  return li
}

const filtersKey = () => `planner:${config.counselling}:filters`

function saveFilters() {
  storage.set(filtersKey(), { ...Object.fromEntries(FACET_NAMES.map((n) => [n, [...state.selected[n]]])), hide: $("#f-hide").checked, group: state.groupBy })
}

function restoreFilters() {
  const saved = storage.get(filtersKey()) || {}
  for (const facet of state.facets) {
    const valid = new Set(facet.values)
    state.selected[facet.name] = new Set((saved[facet.name] || []).filter((v) => valid.has(v)))
  }
  $("#f-hide").checked = Boolean(saved.hide)
  state.groupBy = ["institute", "speciality"].includes(saved.group) ? saved.group : "none"
  renderFacets()
}

function facetLabel(facet, value) {
  return facet.label ? facet.label(value) : value
}

function facetDecor(facet, value) {
  const nodes = []
  if (facet.icon) nodes.push(iconSvg(config.spriteUrl, facet.icon(value), "icon icon-spec"))
  if (facet.badge) nodes.push(badgeEl(facet.badge(value)))
  return nodes
}

function renderFacets() {
  const frag = document.createDocumentFragment()
  const groupSection = make("section", { className: "facet" })
  const groupHead = make("div", { className: "facet-head" })
  groupHead.append(make("h3", { textContent: "Group by" }))
  const groupChips = make("div", { className: "facet-chips", id: "group-by" })
  groupChips.setAttribute("role", "radiogroup")
  groupChips.setAttribute("aria-label", "Group by")
  for (const [value, label] of [["none", "None"], ["institute", "Institute"], ["speciality", "Speciality"]]) {
    const chip = make("button", { type: "button", className: "toggle-chip", textContent: label })
    chip.dataset.group = value
    chip.setAttribute("role", "radio")
    groupChips.append(chip)
  }
  groupSection.append(groupHead, groupChips)
  frag.append(groupSection)
  for (const facet of state.facets) {
    const section = make("section", { className: "facet" })
    section.dataset.facet = facet.name
    const head = make("div", { className: "facet-head" })
    head.append(make("h3", { textContent: facet.title }), make("span", { className: "facet-selected" }))
    section.append(head)
    if (facet.searchable) {
      const search = make("input", { type: "search", className: "facet-search", placeholder: `Search ${facet.values.length} ${facet.title.toLowerCase()} options`, autocomplete: "off" })
      search.dataset.facet = facet.name
      search.setAttribute("aria-label", `Search ${facet.title}`)
      section.append(search)
    }
    section.append(make(facet.mode === "list" ? "ul" : "div", { className: facet.mode === "list" ? "facet-list" : "facet-chips" }))
    frag.append(section)
  }
  $("#facets").replaceChildren(frag)
}

function renderFacetOptions(name) {
  const facet = state.facets.find((f) => f.name === name)
  const section = $(`#facets .facet[data-facet="${name}"]`)
  if (!facet || !section) return
  const counts = facetCounts(name, facet.key)
  const selected = state.selected[name]
  section.querySelector(".facet-selected").textContent = selected.size ? `${selected.size} selected` : ""
  const terms = normalize(section.querySelector(".facet-search")?.value).split(" ").filter(Boolean)
  const values = facet.values.filter((v) => selected.has(v) || terms.every((t) => normalize(facetLabel(facet, v)).includes(t)))
  const ordered = facet.mode === "list" ? [...values.filter((v) => selected.has(v)), ...values.filter((v) => !selected.has(v))] : values
  const box = section.querySelector(".facet-list, .facet-chips")
  const frag = document.createDocumentFragment()
  for (const value of ordered) {
    const on = selected.has(value)
    const count = counts.get(value) || 0
    if (facet.mode === "list") {
      const li = make("li")
      const label = make("label", { className: `facet-option${on ? " on" : ""}${count ? "" : " zero"}` })
      const input = make("input", { type: "checkbox", checked: on, value })
      input.dataset.facet = name
      label.append(input, ...facetDecor(facet, value), make("span", { className: "opt-label", textContent: facetLabel(facet, value) }), make("span", { className: "opt-count", textContent: count.toLocaleString() }))
      li.append(label)
      frag.append(li)
    } else {
      const chip = make("button", { type: "button", className: `toggle-chip${count ? "" : " zero"}` })
      chip.dataset.facet = name
      chip.dataset.value = value
      chip.setAttribute("aria-pressed", String(on))
      chip.append(...facetDecor(facet, value))
      if (!facet.short) chip.append(document.createTextNode(facetLabel(facet, value)))
      chip.append(make("span", { className: "opt-count", textContent: count.toLocaleString() }))
      frag.append(chip)
    }
  }
  if (!ordered.length) frag.append(make("li", { className: "facet-option zero", textContent: "No matches" }))
  box.replaceChildren(frag)
}

function toggleFacet(name, value, on) {
  const set = state.selected[name]
  on ? set.add(value) : set.delete(value)
  saveFilters()
  applyFilters()
}

function activeFilterCount() {
  return FACET_NAMES.reduce((n, name) => n + (state.selected[name].size ? 1 : 0), 0) + ($("#f-hide").checked ? 1 : 0)
}

function refreshFilterUI() {
  const count = activeFilterCount()
  const badge = $("#filters-count")
  badge.hidden = count === 0
  badge.textContent = count
  $("#filters-open").setAttribute("aria-label", count ? `Filters, ${count} active` : "Filters")
  $("#filters-apply").textContent = `Show ${state.filtered.length.toLocaleString()} ${state.filtered.length === 1 ? "choice" : "choices"}`
  for (const chip of document.querySelectorAll("#group-by .toggle-chip")) {
    const on = chip.dataset.group === state.groupBy
    chip.setAttribute("aria-pressed", String(on))
    chip.setAttribute("aria-checked", String(on))
  }
  if (!$("#filter-sheet").hidden) for (const facet of state.facets) renderFacetOptions(facet.name)
  renderChips()
}

function renderChips() {
  const frag = document.createDocumentFragment()
  for (const facet of state.facets) {
    const values = [...state.selected[facet.name]]
    if (!values.length) continue
    const chip = make("button", { type: "button", className: "chip" })
    chip.dataset.clear = facet.name
    chip.setAttribute("aria-label", `Remove ${facet.title} filter`)
    chip.append(...values.slice(0, 3).flatMap((v) => (facet.badge ? [badgeEl(facet.badge(v))] : [])))
    if (facet.icon) chip.append(iconSvg(config.spriteUrl, facet.icon(values[0])))
    const text = values.length === 1 ? facetLabel(facet, values[0]) : `${facetLabel(facet, values[0])} +${values.length - 1}`
    chip.append(make("span", { className: "chip-label", textContent: text }), make("span", { className: "chip-x", textContent: "×" }))
    frag.append(chip)
  }
  if (state.groupBy !== "none") {
    const chip = make("button", { type: "button", className: "chip chip-group" })
    chip.dataset.clear = "group"
    chip.append(make("span", { className: "chip-label", textContent: `Grouped by ${state.groupBy}` }), make("span", { className: "chip-x", textContent: "×" }))
    frag.append(chip)
  }
  if ($("#f-hide").checked) {
    const chip = make("button", { type: "button", className: "chip" })
    chip.dataset.clear = "hide"
    chip.append(make("span", { className: "chip-label", textContent: "Hiding added" }), make("span", { className: "chip-x", textContent: "×" }))
    frag.append(chip)
  }
  const box = $("#active-chips")
  box.replaceChildren(frag)
  box.hidden = !box.children.length
}

function openSheet() {
  for (const facet of state.facets) renderFacetOptions(facet.name)
  $("#sheet-backdrop").hidden = false
  $("#filter-sheet").hidden = false
  document.body.style.overflow = "hidden"
  $("#filters-close").focus()
}

function closeSheet() {
  $("#sheet-backdrop").hidden = true
  $("#filter-sheet").hidden = true
  document.body.style.overflow = ""
  $("#filters-open").focus()
}

const CONFIDENCE_TEXT = {
  high: "DNB-specific contact from the hospital's own pages",
  medium: "Academic office contact, not specific to DNB",
  low: "Only the hospital's general contact was found",
}

function contactLink(kind, raw) {
  const text = String(raw)
  const value = kind === "tel" ? (text.match(/\+?\d[\d\s-]{7,}\d/) || [""])[0].replace(/[\s-]/g, "") : (text.match(/[\w.+-]+@[\w-]+(\.[\w-]+)+/) || [""])[0]
  if (!value) return make("span", { textContent: text })
  const a = make("a", { href: `${kind === "tel" ? "tel:" : "mailto:"}${value}`, className: "contact-link" })
  a.append(iconSvg(config.spriteUrl, kind === "tel" ? "phone" : "mail"), make("span", { textContent: text }))
  return a
}

function contactRow(label, node) {
  const row = make("div", { className: "contact-row" })
  row.append(make("span", { className: "contact-label", textContent: label }), node)
  return row
}

function openContact(c) {
  const info = state.contacts[c.inst.code]
  if (!info) return
  const body = $("#contact-body")
  const frag = document.createDocumentFragment()
  const head = make("div", { className: "contact-head" })
  head.append(make("strong", { textContent: c.inst.short }), make("span", { className: "muted", textContent: info.hospital || c.inst.name }))
  frag.append(head)
  const level = make("p", { className: `confidence confidence-${info.confidence}`, textContent: CONFIDENCE_TEXT[info.confidence] || "" })
  frag.append(level)
  if (info.dnb_contact_name) frag.append(contactRow("Contact", make("span", { textContent: [info.dnb_contact_name, info.designation].filter(Boolean).join(" — ") })))
  else if (info.designation) frag.append(contactRow("Office", make("span", { textContent: info.designation })))
  if (info.phone) frag.append(contactRow("Phone", contactLink("tel", info.phone)))
  if (info.email) frag.append(contactRow("Email", contactLink("mailto", info.email)))
  for (const other of info.other_contacts || []) {
    const kind = /@/.test(other.value) ? "mailto" : /\d{6,}/.test(other.value.replace(/[\s-]/g, "")) ? "tel" : null
    frag.append(contactRow(other.label, kind ? contactLink(kind, other.value) : make("span", { textContent: other.value })))
  }
  if (info.orthopaedics_notes) frag.append(contactRow("Orthopaedics", make("span", { textContent: info.orthopaedics_notes })))
  if (info.notes) frag.append(contactRow("Notes", make("span", { textContent: info.notes })))
  const sources = make("div", { className: "contact-sources" })
  for (const url of info.sources || []) {
    const a = make("a", { href: url, target: "_blank", rel: "noopener", className: "contact-link" })
    a.append(iconSvg(config.spriteUrl, "external-link"), make("span", { textContent: url.replace(/^https?:\/\/(www\.)?/, "") }))
    sources.append(a)
  }
  frag.append(contactRow(`Sources${info.researched_on ? ` (checked ${info.researched_on})` : ""}`, sources))
  body.replaceChildren(frag)
  $("#sheet-backdrop").hidden = false
  $("#contact-sheet").hidden = false
  document.body.style.overflow = "hidden"
  $("#contact-close").focus()
}

function closeContact() {
  if ($("#contact-sheet").hidden) return
  $("#contact-sheet").hidden = true
  $("#sheet-backdrop").hidden = !$("#filter-sheet").hidden ? false : true
  document.body.style.overflow = ""
}

function showTab(name) {
  for (const btn of document.querySelectorAll(".tabs button")) btn.classList.toggle("active", btn.dataset.tab === name)
  for (const pane of document.querySelectorAll(".pane")) pane.classList.toggle("active", pane.dataset.pane === name)
}

function bind() {
  let debounce
  $("#q").addEventListener("input", () => {
    clearTimeout(debounce)
    debounce = setTimeout(() => applyFilters(), 120)
  })
  $("#f-hide").addEventListener("change", () => {
    saveFilters()
    applyFilters()
  })
  $("#clear-filters").addEventListener("click", () => {
    for (const n of FACET_NAMES) state.selected[n].clear()
    state.groupBy = "none"
    $("#f-hide").checked = false
    for (const input of document.querySelectorAll(".facet-search")) input.value = ""
    saveFilters()
    applyFilters()
  })
  $("#filters-open").addEventListener("click", openSheet)
  $("#filters-close").addEventListener("click", closeSheet)
  $("#filters-apply").addEventListener("click", closeSheet)
  $("#sheet-backdrop").addEventListener("click", () => {
    closeSheet()
    closeContact()
  })
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !$("#filter-sheet").hidden) closeSheet()
    if (e.key === "Escape" && !$("#contact-sheet").hidden) closeContact()
  })
  $("#facets").addEventListener("change", (e) => {
    const input = e.target.closest("input[data-facet]")
    if (input) toggleFacet(input.dataset.facet, input.value, input.checked)
  })
  $("#facets").addEventListener("click", (e) => {
    const groupChip = e.target.closest("button[data-group]")
    if (groupChip) {
      state.groupBy = groupChip.dataset.group
      state.expanded.clear()
      saveFilters()
      applyFilters()
      return
    }
    const chip = e.target.closest("button[data-facet]")
    if (chip) toggleFacet(chip.dataset.facet, chip.dataset.value, chip.getAttribute("aria-pressed") !== "true")
  })
  $("#facets").addEventListener("input", (e) => {
    if (e.target.matches(".facet-search")) renderFacetOptions(e.target.dataset.facet)
  })
  $("#active-chips").addEventListener("click", (e) => {
    const chip = e.target.closest("[data-clear]")
    if (!chip) return
    if (chip.dataset.clear === "hide") $("#f-hide").checked = false
    else if (chip.dataset.clear === "group") state.groupBy = "none"
    else state.selected[chip.dataset.clear].clear()
    saveFilters()
    applyFilters()
  })
  $("#more").addEventListener("click", () => {
    state.shown += PAGE_SIZE
    renderResults()
  })
  $("#add-all").addEventListener("click", () => {
    const ids = state.filtered.filter((c) => !state.pickIndex.has(c.id)).map((c) => c.id)
    const btn = $("#add-all")
    if (ids.length > 1 && btn.dataset.armed !== "1") {
      btn.dataset.armed = "1"
      btn.textContent = `Click again to add ${ids.length.toLocaleString()}`
      setTimeout(() => {
        btn.dataset.armed = ""
        renderResults()
      }, 3000)
      return
    }
    btn.dataset.armed = ""
    addChoices(ids)
  })

  for (const list of ["#results", "#picks"]) {
    $(list).addEventListener("click", (e) => {
      const btn = e.target.closest(".contact-btn")
      if (!btn) return
      e.stopPropagation()
      const choice = btn.dataset.code ? state.choices.find((c) => c.inst.code === btn.dataset.code) : state.byId.get(Number(btn.closest("li[data-id]").dataset.id))
      openContact(choice)
    }, true)
  }
  $("#contact-close").addEventListener("click", closeContact)

  $("#results").addEventListener("click", (e) => {
    const group = e.target.closest("li.group")
    if (group && e.target.closest(".g-more")) {
      state.expanded.has(group.dataset.group) ? state.expanded.delete(group.dataset.group) : state.expanded.add(group.dataset.group)
      renderResults()
      return
    }
    if (group && e.target.closest(".g-addall")) {
      const items = groupsOf(state.filtered).find((g) => g.key === group.dataset.group)?.items || []
      addChoices(items.map((c) => c.id))
      return
    }
    const btn = e.target.closest(".r-add")
    if (!btn) return
    const id = Number(btn.closest("li[data-id]").dataset.id)
    if (state.pickIndex.has(id)) {
      showTab("order")
      flash(id)
    } else {
      addChoices([id])
    }
  })

  const picks = $("#picks")
  const indexOf = (el) => state.pickIndex.get(Number(el.closest("li").dataset.id))
  picks.addEventListener("click", (e) => {
    if (!e.target.closest("li")) return
    const i = indexOf(e.target)
    if (e.target.closest(".p-main")) {
      const id = Number(e.target.closest("li").dataset.id)
      state.openPick = state.openPick === id ? null : id
      for (const li of picks.children) li.classList.toggle("open", Number(li.dataset.id) === state.openPick)
    } else if (e.target.closest(".p-gather")) gatherInstitute(i)
    else if (e.target.closest(".p-up")) move(i, i - 1)
    else if (e.target.closest(".p-down")) move(i, i + 1)
    else if (e.target.closest(".p-remove")) {
      state.picks.splice(i, 1)
      changed()
    }
  })
  picks.addEventListener("change", (e) => {
    if (!e.target.matches(".p-pos")) return
    const i = indexOf(e.target)
    const to = parseInt(e.target.value, 10)
    if (Number.isFinite(to)) move(i, to - 1)
    else e.target.value = i + 1
  })
  picks.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && e.target.matches(".p-pos, .p-note")) e.target.blur()
  })
  picks.addEventListener("input", (e) => {
    if (!e.target.matches(".p-note")) return
    state.picks[indexOf(e.target)].note = e.target.value
    scheduleSave()
  })
  $("#order-q").addEventListener("input", filterPicks)
  $("#order-view").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-view]")
    if (btn) setOrderView(btn.dataset.view)
  })
  $("#picks-review").addEventListener("click", (e) => {
    const together = e.target.closest(".g-together")
    if (together) {
      gatherInstitute(Number(together.dataset.rank) - 1)
      return
    }
  const row = e.target.closest("li[data-id]")
  if (!row) return
  const id = Number(row.dataset.id)
  const index = state.pickIndex.get(id)
  if (e.target.closest(".review-show")) {
    setOrderView("ranked")
    state.openPick = id
    renderPicks()
    flash(id)
  } else if (e.target.closest(".review-remove")) {
    state.picks.splice(index, 1)
    state.reviewOpen = null
    changed()
  } else if (!e.target.closest(".r-tools")) {
    state.reviewOpen = state.reviewOpen === id ? null : id
    renderReview()
  }
})
$("#picks-review").addEventListener("change", (e) => {
  if (!e.target.matches(".review-pos")) return
  const id = Number(e.target.closest("li[data-id]").dataset.id)
  const to = parseInt(e.target.value, 10)
  if (Number.isFinite(to)) move(state.pickIndex.get(id), to - 1)
})

  window.Sortable?.create(picks, {
    handle: ".handle",
    animation: 120,
    onEnd: ({ oldIndex, newIndex }) => move(oldIndex, newIndex),
  })

  for (const btn of document.querySelectorAll(".tabs button")) btn.addEventListener("click", () => showTab(btn.dataset.tab))
  $("#export").addEventListener("click", exportCsv)
  if (document.documentElement.dataset.choiceFiller) fillerReady()
  document.addEventListener("choice-filler:ready", fillerReady)
  document.addEventListener("choice-filler:import", offerMccImport)
  $("#mcc-import-apply").addEventListener("click", applyMccImport)
  $("#mcc-import-close").onclick = closeMccImport
  $("#history-toggle")?.addEventListener("click", openHistory)
  $("#history-close").addEventListener("click", () => ($("#history").hidden = true))

  $("#sign-out")?.addEventListener("submit", async (e) => {
    if (state.conflict) {
      e.preventDefault()
      setStatus("Choose which order to keep before signing out.", true)
      return
    }
    if (state.saving || state.dirty) {
      e.preventDefault()
      setStatus("Wait for your changes to sync before signing out.", true)
      return
    }
    e.preventDefault()
    try {
      await caches?.delete("planner-v1")
    } catch {}
    for (const key of Object.keys(localStorage)) {
      if (key.startsWith("planner:") && key.includes(":account:")) storage.remove(key)
    }
    e.target.submit()
  })

  window.addEventListener("online", () => {
    if (synced() && state.dirty && !state.conflict) save()
  })
  window.addEventListener("offline", () => setStatus("Offline — changes are saved on this device"))
  window.addEventListener("beforeunload", (e) => {
    if (synced() && (state.saving || (state.dirty && navigator.onLine))) e.preventDefault()
  })
}

async function boot() {
  showTab("catalog")
  setStatus("Loading…")
  const catalog = await api(config.catalogUrl)
  buildCatalog(catalog)
  bind()
  if (synced()) await loadSynced()
  else loadDevice()
  renderPicks()
  applyFilters()
  let savedView = "ranked"
  try {
    savedView = localStorage.getItem(`planner:${config.counselling}:order-view`) || "ranked"
  } catch {}
  setOrderView(["ranked", "institute", "speciality"].includes(savedView) ? savedView : "ranked")
}

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch(() => {})
}

if (root) boot().catch((err) => setStatus(`Failed to load: ${err.message}`, true))
