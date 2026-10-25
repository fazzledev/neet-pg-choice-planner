import "sortablejs"
import { Turbo } from "@hotwired/turbo-rails"

Turbo.session.drive = false
Turbo.StreamActions.plan_changed = function () {
  const revision = Number(this.getAttribute("revision"))
  if (revision > (state.remoteRevision ?? 0)) state.remoteRevision = revision
  catchUp()
}

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
  locationsUrl: root.dataset.locationsUrl,
  mapCssUrl: root.dataset.mapCssUrl,
  mapShapeUrl: root.dataset.mapShapeUrl,
  cutoffsUrl: root.dataset.cutoffsUrl,
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
  catalogView: "list",
  locations: null,
  mapPoint: null,
  openDetails: new Set(),
  mapPoints: new Map(),
  refitMap: false,
  mapSubject: "plan",
  mapLens: true,
  planDepth: null,
  likelyOnly: false,
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

const USAGE_OUTBOX = "planner:usage-outbox"
const USAGE_OUTBOX_LIMIT = 50
const EXTENSION_USAGE = /^extension\/[a-z0-9-]+(\/[a-z0-9-]+)?$/
const tracked = new Set()

function track(event) {
  const name = `${synced() ? "account" : "guest"}/${event}`
  if (tracked.has(name)) return
  tracked.add(name)
  queueUsage([name])
}

function queueUsage(names) {
  storage.set(USAGE_OUTBOX, [...(storage.get(USAGE_OUTBOX) || []), ...names].slice(-USAGE_OUTBOX_LIMIT))
  sendUsage()
}

function sendUsage() {
  if (!navigator.onLine || !window.goatcounter?.count) return
  const outbox = storage.get(USAGE_OUTBOX) || []
  if (!outbox.length) return
  storage.remove(USAGE_OUTBOX)
  for (const name of outbox) window.goatcounter.count({ path: name, title: name, event: true })
}

function receiveExtensionUsage(event) {
  const names = JSON.parse(event.detail)
  if (!Array.isArray(names)) return
  const accepted = names.filter((name) => typeof name === "string" && EXTENSION_USAGE.test(name))
  if (accepted.length) queueUsage(accepted)
}

function planSizeBucket(count) {
  if (count === 0) return "0"
  if (count <= 10) return "1-10"
  if (count <= 50) return "11-50"
  if (count <= 200) return "51-200"
  return "201-plus"
}

function trackPlanSize() {
  if (document.visibilityState !== "hidden" || !state.editedThisVisit || state.planSizeTracked) return
  state.planSizeTracked = true
  track(`plan-size/${planSizeBucket(state.picks.length)}`)
}

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
  if (resetPaging) state.refitMap = true
  renderResults()
  refreshFilterUI()
}

const GROUP_PAGE = 30
const GROUP_PREVIEW = 3

function paintInfoToggle(btn, inst) {
  const open = state.openDetails.has(inst.code)
  btn.dataset.code = inst.code
  btn.setAttribute("aria-expanded", String(open))
  btn.setAttribute("aria-label", `Official name and address of ${inst.short}`)
  btn.title = "Official name and address"
  return btn
}

function infoToggle(inst) {
  const btn = make("button", { type: "button", className: "info-btn" })
  btn.append(iconSvg(config.spriteUrl, "info"))
  return paintInfoToggle(btn, inst)
}

function instDetails(inst) {
  const box = make("div", { className: "inst-details" })
  box.dataset.code = inst.code
  box.hidden = !state.openDetails.has(inst.code)
  box.append(make("span", { className: "inst-official", textContent: inst.name }))
  if (inst.address && !normalize(inst.name).includes(normalize(inst.address))) box.append(make("span", { className: "inst-address", textContent: inst.address }))
  return box
}

function resultItem(c) {
  const li = $("#result-tpl").content.firstElementChild.cloneNode(true)
  li.dataset.id = c.id
  const title = li.querySelector(".r-inst")
  title.replaceChildren(make("span", { textContent: c.inst.short }), infoToggle(c.inst))
  title.after(instDetails(c.inst))
  const meta = li.querySelector(".r-meta")
  meta.replaceChildren(...stateNodes(c.inst), document.createTextNode(` · ${c.quota} · ${TYPE_SHORT[c.inst.typeCode] || c.inst.typeName}`))
  meta.title = c.inst.doubtful ? DOUBTFUL_HINT : c.inst.typeName
  if (c.inst.doubtful) meta.title = DOUBTFUL_HINT
  const prog = li.querySelector(".r-prog")
  prog.replaceChildren(...programNodes(c))
  prog.title = c.program
  li.querySelector(".contact-btn").hidden = !state.contacts[c.inst.code]
  paintCutoff(li.querySelector(".cutoff"), c)
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

function groupsOf(choices, by = state.groupBy) {
  const key = by === "institute" ? (c) => c.inst.code : (c) => c.speciality
  const groups = new Map()
  for (const c of choices) {
    const k = key(c)
    if (!groups.has(k)) groups.set(k, [])
    groups.get(k).push(c)
  }
  const label = (items) => (by === "institute" ? items[0].inst.short : items[0].speciality)
  return [...groups.entries()].map(([k, items]) => ({ key: k, items, label: label(items) })).sort((a, b) => a.label.localeCompare(b.label))
}

function groupCard(group, mode = state.groupBy) {
  const first = group.items[0]
  const li = make("li", { className: "group" })
  li.dataset.group = group.key
  const head = make("div", { className: "g-head" })
  if (mode === "speciality") head.append(make("span", { className: "g-icon" }))
  if (mode === "speciality") head.firstChild.append(iconSvg(config.spriteUrl, first.icon, "icon icon-spec"))
  const text = make("div", { className: "g-text" })
  const picked = group.items.filter((c) => state.pickIndex.has(c.id)).length
  const count = `${group.items.length} ${mode === "institute" ? (group.items.length === 1 ? "program" : "programs") : group.items.length === 1 ? "institute" : "institutes"}${picked ? ` · ${picked} in your plan` : ""}`
  if (mode === "institute") {
    const titleRow = make("span", { className: "g-title-row" })
    titleRow.append(make("span", { className: "g-title", textContent: group.label }), infoToggle(first.inst))
    const meta = make("span", { className: "g-meta" })
    meta.append(...stateNodes(first.inst), document.createTextNode(` · ${TYPE_SHORT[first.inst.typeCode] || first.inst.typeName} · ${count}`))
    text.append(titleRow, meta, instDetails(first.inst))
  } else {
    text.append(make("span", { className: "g-title", textContent: group.label }))
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
  if (state.catalogView === "map") {
    renderMapResults()
    return
  }
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
  paintAddAll()
}

function paintAddAll() {
  const addable = state.filtered.filter((c) => !state.pickIndex.has(c.id)).length
  const addAll = $("#add-all")
  addAll.hidden = addable === 0 || addable === state.choices.length
  addAll.textContent = `Add all ${addable.toLocaleString()}`
}

let catalogMap = null
let catalogMapLoading = null

function plural(n, one, many = `${one}s`) {
  return `${n.toLocaleString()} ${n === 1 ? one : many}`
}

const CHANCE_ORDER = ["likely", "possible", "borderline", "reach", "none"]
const CHANCE_WORDS = { likely: "Likely", possible: "Possible", borderline: "Borderline", reach: "Reach", none: "No past data" }
const mapSubjectKey = () => `planner:${config.counselling}:map-subject`
const mapLensKey = () => `planner:${config.counselling}:map-lens`

function lensOn() {
  return state.mapLens && Boolean(state.profile.rank) && Boolean(state.cutoffs)
}

function closingFor(c) {
  const mains = cutoffYears(c).map((year) => year.main).filter(Boolean)
  return mains.length ? Math.min(...mains) : null
}

const chanceCache = new Map()

function chanceFor(c) {
  if (!chanceCache.has(c.id)) {
    const closing = closingFor(c)
    chanceCache.set(c.id, closing ? chanceOf(state.profile.rank, closing)[1] : "none")
  }
  return chanceCache.get(c.id)
}

function bestChance(chances) {
  return chances.reduce((best, chance) => (CHANCE_ORDER.indexOf(chance) < CHANCE_ORDER.indexOf(best) ? chance : best), "none")
}

function placeOf(c) {
  const place = state.locations?.[c.inst.code]
  return place && { key: `${place[0]},${place[1]}`, lat: place[0], lng: place[1], city: place[2] }
}

function rankList(ranks) {
  const shown = ranks.slice(0, 3).map((rank) => `#${rank}`).join(" ")
  return ranks.length > 3 ? `${shown} +${ranks.length - 3}` : shown
}

function mapPoints() {
  const lens = lensOn()
  const points = new Map()
  const unplaced = new Set()
  for (const c of state.filtered) {
    const chance = lens ? chanceFor(c) : null
    if (state.likelyOnly && lens && chance !== "likely") continue
    const place = placeOf(c)
    if (!place) {
      unplaced.add(c.inst.code)
      continue
    }
    if (!points.has(place.key)) points.set(place.key, { ...place, institutes: new Map(), choices: 0, ranks: [], chances: [] })
    const point = points.get(place.key)
    if (!point.institutes.has(c.inst.code)) point.institutes.set(c.inst.code, [])
    point.institutes.get(c.inst.code).push(c)
    point.choices += 1
    if (chance) point.chances.push(chance)
    if (state.pickIndex.has(c.id)) point.ranks.push(state.pickIndex.get(c.id) + 1)
  }
  for (const point of points.values()) {
    point.ranks.sort((a, b) => a - b)
    const inPlan = point.ranks.length > 0
    const best = lens ? bestChance(point.chances) : null
    point.best = best
    point.fill = lens ? `--chance-${best}` : inPlan ? "--accent" : "--accent-soft"
    point.stroke = lens ? "--bg" : "--accent"
    point.opacity = lens && !inPlan && (best === "reach" || best === "none") ? 0.4 : 1
    point.ring = lens && inPlan
    point.name = inPlan ? `${point.city} ${rankList(point.ranks)}` : point.city
    point.priority = point.institutes.size
    point.label = `${point.city} · ${plural(point.institutes.size, "institute")} · ${plural(point.choices, "choice")}${best ? ` · best odds ${CHANCE_WORDS[best]}` : ""}${inPlan ? ` · your ${rankList(point.ranks)}` : ""}`
    point.radius = Math.min(14, 3 + 1.4 * Math.sqrt(point.institutes.size))
  }
  return { points, unplaced: unplaced.size }
}

function planDepth() {
  return Math.min(state.planDepth ?? state.picks.length, state.picks.length)
}

function planOutlook() {
  const lens = lensOn()
  const entries = state.picks.map((pick, i) => {
    const c = state.byId.get(pick.choice_id)
    return { c, rank: i + 1, chance: lens ? chanceFor(c) : null }
  })
  const firstLikely = lens ? entries.find((e) => e.chance === "likely") : null
  const depth = planDepth()
  const shown = entries.slice(0, depth)
  const landing = firstLikely && firstLikely.rank <= depth ? firstLikely : null
  return { lens, entries, shown, depth, firstLikely, landing }
}

function planPoints(outlook) {
  const points = new Map()
  let unplaced = 0
  for (const entry of outlook.shown) {
    const place = placeOf(entry.c)
    if (!place) {
      unplaced += 1
      continue
    }
    if (!points.has(place.key)) points.set(place.key, { ...place, entries: [], institutes: new Set() })
    const point = points.get(place.key)
    point.entries.push(entry)
    point.institutes.add(entry.c.inst.code)
  }
  for (const point of points.values()) {
    const ranks = point.entries.map((e) => e.rank)
    const before = point.entries.filter((e) => !outlook.landing || e.rank <= outlook.landing.rank)
    const fallback = outlook.lens && before.length === 0
    const best = outlook.lens && !fallback ? bestChance(before.map((e) => e.chance)) : null
    point.ranks = ranks
    point.landing = Boolean(outlook.landing && point.entries.includes(outlook.landing))
    point.fallback = fallback
    point.fill = !outlook.lens ? "--accent" : fallback ? null : `--chance-${best}`
    point.stroke = fallback ? "--faint" : "--bg"
    point.opacity = 1
    point.ring = point.landing
    point.name = `${point.city} ${rankList(ranks)}`
    point.priority = -ranks[0]
    point.label = `${point.city} · your ${ranks.map((rank) => `#${rank}`).join(", ")}${point.landing ? " · most likely landing" : fallback ? " · fallbacks only" : best ? ` · best odds ${CHANCE_WORDS[best]}` : ""}`
    point.radius = Math.min(14, 4 + 1.6 * Math.sqrt(ranks.length))
  }
  return { points, unplaced }
}

function mapPanelGroups() {
  const point = state.mapPoints?.get(state.mapPoint)
  if (!point || !point.institutes || state.mapSubject === "plan") return []
  return [...point.institutes.values()].map((items) => ({ key: items[0].inst.code, items, label: items[0].inst.short })).sort((a, b) => a.label.localeCompare(b.label))
}

function renderMapResults() {
  const plan = state.mapSubject === "plan"
  $(".pane.catalog").classList.toggle("map-plan", plan)
  for (const btn of document.querySelectorAll("#map-subject button")) btn.setAttribute("aria-checked", String(btn.dataset.subject === state.mapSubject))
  $("#map-lens").disabled = !state.profile.rank || !state.cutoffs
  $("#map-lens").checked = state.mapLens && !$("#map-lens").disabled
  $("#more").hidden = true
  $("#add-all").hidden = plan
  if (!plan) paintAddAll()
  const outlook = plan ? planOutlook() : null
  if (plan) $("#result-count").textContent = `${plural(state.picks.length, "choice")} in your plan`
  else {
    const institutes = new Set(state.filtered.map((c) => c.inst.code)).size
    $("#result-count").textContent = `${plural(institutes, "institute")} · ${plural(state.filtered.length, "choice")}`
  }
  if (!catalogMap) return
  const { points, unplaced } = plan ? planPoints(outlook) : mapPoints()
  state.mapPoints = points
  if (!points.has(state.mapPoint)) state.mapPoint = null
  catalogMap.show([...points.values()], { fit: state.refitMap, selected: state.mapPoint })
  state.refitMap = false
  renderMapDepth(outlook)
  renderMapCard(outlook, points)
  renderMapLegend(plan)
  const hint = plan
    ? state.picks.length ? "Each pin is a city, labelled with your ranks there. Tap one to see those choices." : ""
    : state.filtered.length ? "Each pin is a city. Tap one to see its institutes." : "No choices match these filters."
  const lost = plan ? `${plural(unplaced, "choice")} in your plan could not be placed on the map.` : `${plural(unplaced, "institute")} could not be placed on the map; switch to List to see them.`
  $("#map-hint").textContent = [hint, unplaced ? lost : ""].filter(Boolean).join(" ")
  renderMapPanel(outlook)
}

function renderMapDepth(outlook) {
  const box = $("#map-depth")
  box.hidden = !outlook || state.picks.length < 2
  if (box.hidden) return
  const input = $("#map-depth-input")
  input.max = state.picks.length
  input.value = outlook.depth
  input.setAttribute("aria-valuetext", `choices #1 to #${outlook.depth}`)
  $("#map-depth-label").textContent = `Show choices #1 to #${outlook.depth}`
  const marker = $("#map-depth-marker")
  marker.hidden = !outlook.firstLikely
  if (outlook.firstLikely) {
    marker.textContent = `Likely from #${outlook.firstLikely.rank}`
    marker.style.left = `${((outlook.firstLikely.rank - 1) / Math.max(1, state.picks.length - 1)) * 100}%`
  }
}

function cardNodes(tone, eyebrow, lines, action) {
  const nodes = [make("span", { className: `map-card-eyebrow ${tone}`, textContent: eyebrow })]
  for (const [text, className] of lines) nodes.push(make("span", { className: className || "", textContent: text }))
  if (action) {
    const btn = make("button", { type: "button", className: "primary map-card-action", textContent: action.label })
    btn.dataset.action = action.name
    nodes.push(btn)
  }
  return nodes
}

function renderMapCard(outlook, points) {
  const card = $("#map-card")
  const rank = state.profile.rank
  let content = null
  let tone = "neutral"
  if (state.mapSubject === "plan" && !state.picks.length) {
    content = cardNodes("neutral", "Your plan is empty", [["Add choices from the catalog, then come back to see where they are."]], { name: "show-all", label: "Show all seats" })
  } else if (!rank) {
    content = cardNodes("neutral", "Where would you most likely land?", [["Add your NEET PG rank and category. Each city is then coloured by your odds there, and your most likely choice is marked."]], { name: "add-rank", label: "Add your rank" })
  } else if (!state.cutoffs) {
    content = state.cutoffsFailed
      ? cardNodes("neutral", "Couldn't load past closing ranks", [["Check your connection and reload the page to see your odds."]], { name: "add-rank", label: "Change your rank" })
      : cardNodes("neutral", "Loading past closing ranks", [["Your odds appear here once they load."]])
  } else if (!lensOn()) {
    content = null
  } else if (state.mapSubject === "plan") {
    const { landing, firstLikely, depth, shown } = outlook
    if (landing) {
      tone = "likely"
      const above = landing.rank - 1
      const below = shown.length - landing.rank
      const closing = closingFor(landing.c)
      content = cardNodes("likely", `Most likely: your #${landing.rank}`, [
        [landing.c.inst.short, "map-card-title"],
        [`${landing.c.program}${closing ? ` · last closed at ${rankFormat.format(closing)}` : ""}`, "map-card-muted"],
        [above ? `Above it: ${plural(above, "choice")} you get only if cutoffs fall your way` : "It is your first choice.", "map-card-muted"],
        [below ? `Below it: ${plural(below, "fallback")} if it doesn't work out` : "Nothing below it on the map.", "map-card-muted"],
      ])
    } else if (firstLikely) {
      tone = "borderline"
      content = cardNodes("borderline", `Through #${depth}: nothing likely yet`, [[`None of these look Likely at rank ${rankFormat.format(rank)}. You'd get one only if this year's cutoffs fall your way.`], [`Your first Likely choice is #${firstLikely.rank}, in ${placeOf(firstLikely.c)?.city || firstLikely.c.inst.short}.`, "map-card-muted"]], { name: "depth-all", label: "Show the whole plan" })
    } else {
      tone = "borderline"
      content = cardNodes("borderline", `None of your ${plural(state.picks.length, "choice")} look Likely`, [[`At rank ${rankFormat.format(rank)}, if this year's cutoffs land near past years, this list may not get you a seat. Add a few Likely seats below your favourites as a safety net.`]], { name: "show-likely", label: "Show Likely seats on the map" })
    }
  } else {
    const likelyCities = [...points.values()].filter((p) => p.best === "likely").length
    const likelyPicks = state.picks.filter((pick) => chanceFor(state.byId.get(pick.choice_id)) === "likely").length
    tone = "likely"
    content = cardNodes("likely", `${plural(likelyCities, "city", "cities")} with a Likely seat`, [[`for these filters at rank ${rankFormat.format(rank)}.`], [likelyPicks ? `${plural(likelyPicks, "choice")} in your plan look Likely.` : "None of the choices in your plan look Likely yet.", "map-card-muted"]], { name: "toggle-likely", label: state.likelyOnly ? "Show every city" : "Show only Likely cities" })
  }
  card.hidden = !content
  card.className = `map-card ${tone}`
  const text = content ? content.map((node) => node.textContent).join("\n") : ""
  if (content && card.dataset.text !== text) card.replaceChildren(...content)
  card.dataset.text = text
}

function renderMapLegend(plan) {
  const legend = $("#map-legend")
  const lens = lensOn()
  legend.hidden = !lens
  if (!lens) return
  const title = make("span", { className: "map-legend-title" })
  const change = make("button", { type: "button", className: "button-link map-legend-change", textContent: "Change" })
  change.dataset.action = "add-rank"
  change.setAttribute("aria-label", "Change your rank or category")
  title.append(`Odds at rank ${rankFormat.format(state.profile.rank)}`, change)
  const rows = [title]
  for (const kind of ["reach", "borderline", "possible", "likely", "none"]) {
    const row = make("span", { className: "map-legend-row" })
    row.append(make("span", { className: `map-swatch chance-fill-${kind}` }), document.createTextNode(CHANCE_WORDS[kind]))
    rows.push(row)
  }
  const ring = make("span", { className: "map-legend-row" })
  ring.append(make("span", { className: "map-swatch ring" }), document.createTextNode(plan ? "Most likely landing" : "In your plan"))
  rows.push(ring)
  if (plan) {
    const hollow = make("span", { className: "map-legend-row" })
    hollow.append(make("span", { className: "map-swatch hollow" }), document.createTextNode("Only fallbacks there"))
    rows.push(hollow)
  }
  rows.push(make("span", { className: "map-legend-note", textContent: "From past closing ranks. A rough guide, not a prediction." }))
  legend.replaceChildren(...rows)
}

function planPanelRows(point, outlook) {
  return point.entries.map((entry) => {
    const li = make("li", { className: "map-plan-row" })
    li.dataset.id = entry.c.id
    const text = make("span", { className: "map-plan-text" })
    const actions = make("span", { className: "map-plan-actions" })
    if (entry.chance) actions.append(make("span", { className: `chance chance-${entry.chance}`, textContent: outlook.landing === entry ? "Most likely" : CHANCE_WORDS[entry.chance] }))
    actions.append(make("button", { type: "button", className: "button-link map-plan-show", textContent: "Show in plan" }))
    text.append(make("span", { className: "g-row-title", textContent: entry.c.inst.short, title: entry.c.inst.name }), make("span", { className: "g-row-meta", textContent: `${entry.c.program} · ${entry.c.quota}` }), actions)
    li.append(make("span", { className: "rank-chip", textContent: `#${entry.rank}` }), text)
    return li
  })
}

function renderMapPanel(outlook) {
  const point = state.mapPoints.get(state.mapPoint)
  const panel = $("#map-panel")
  panel.hidden = !point
  if (!point) return
  $("#map-panel-title").textContent = point.city
  if (state.mapSubject === "plan") {
    $("#map-panel-note").textContent = `${plural(point.entries.length, "choice")} in your plan`
    $("#map-results").replaceChildren(...planPanelRows(point, outlook))
    return
  }
  const groups = mapPanelGroups()
  const picked = groups.flatMap((g) => g.items).filter((c) => state.pickIndex.has(c.id)).length
  $("#map-panel-note").textContent = `${plural(groups.length, "institute")} · ${plural(point.choices, "choice")}${picked ? ` · ${picked} in your plan` : ""}`
  $("#map-results").replaceChildren(...groups.map((g) => groupCard(g, "institute")))
}

function selectMapPoint(key) {
  state.mapPoint = state.mapSubject === "plan" && state.mapPoint === key ? null : key
  track(`map/opened-pin/${state.mapSubject}`)
  renderMapResults()
  if (state.mapPoint) catalogMap.reveal(key)
  if (state.mapPoint && matchMedia("(max-width: 900px)").matches) $("#map-panel").scrollIntoView({ behavior: "smooth", block: "start" })
}

function setMapSubject(subject) {
  if (state.mapSubject === subject) return
  state.mapSubject = subject
  state.mapPoint = null
  state.likelyOnly = false
  state.refitMap = true
  storage.set(mapSubjectKey(), subject)
  track(`map/subject/${subject}`)
  renderMapResults()
}

function mapCardAction(name, opener) {
  if (name === "show-all") setMapSubject("all")
  else if (name === "add-rank") {
    openSheet(opener)
    $("#my-rank").focus()
  } else if (name === "depth-all") {
    state.planDepth = null
    renderMapResults()
  } else if (name === "show-likely") {
    setMapSubject("all")
    state.likelyOnly = true
    state.refitMap = true
    renderMapResults()
  } else if (name === "toggle-likely") {
    state.likelyOnly = !state.likelyOnly
    state.mapPoint = null
    state.refitMap = true
    renderMapResults()
  }
}

function loadCatalogMap() {
  catalogMapLoading ||= (async () => {
    $("#map-hint").textContent = "Loading the map…"
    const css = make("link", { rel: "stylesheet", href: config.mapCssUrl })
    const cssReady = new Promise((resolve) => {
      css.onload = resolve
      css.onerror = resolve
    })
    document.head.append(css)
    const [{ createMap }, locations, shape] = await Promise.all([import("catalog_map"), api(config.locationsUrl), api(config.mapShapeUrl), cssReady])
    state.locations = locations
    catalogMap = createMap($("#map-canvas"), { onSelect: selectMapPoint, shape })
  })().catch((err) => {
    catalogMapLoading = null
    $("#map-hint").textContent = `Could not load the map (${err.message}). Check your connection and reload the page.`
    throw err
  })
  return catalogMapLoading
}

const catalogViewKey = () => `planner:${config.counselling}:catalog-view`

async function setCatalogView(view) {
  state.catalogView = view
  storage.set(catalogViewKey(), view)
  if ($(".pane.catalog").classList.contains("active")) {
    for (const btn of document.querySelectorAll(".tabs button")) btn.classList.toggle("active", btn.dataset.tab === (view === "map" ? "map" : "catalog"))
  }
  for (const btn of document.querySelectorAll("#catalog-view button")) btn.setAttribute("aria-checked", String(btn.dataset.view === view))
  const map = view === "map"
  $("#results").hidden = map
  $("#catalog-map").hidden = !map
  $(".map-toolbar").hidden = !map
  if (!map) $(".pane.catalog").classList.remove("map-plan")
  if (!map) {
    renderResults()
    return
  }
  state.refitMap = true
  renderResults()
  try {
    await loadCatalogMap()
  } catch {
    return
  }
  if (state.catalogView !== "map") return
  catalogMap.resize()
  state.refitMap = true
  renderMapResults()
}

function paintResult(li, id) {
  const at = state.pickIndex.get(id)
  const btn = li.querySelector(".r-add")
  li.classList.toggle("added", at !== undefined)
  if (at === undefined) btn.textContent = "+"
  else btn.replaceChildren(iconSvg(config.spriteUrl, "check"), `#${at + 1}`)
  btn.setAttribute("aria-label", at === undefined ? "Add to end of my plan" : `In my plan at number ${at + 1}, show it`)
}

function repaintVisibleResults() {
  if (state.groupBy !== "none" || state.catalogView === "map") {
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
    paintInfoToggle(li.querySelector(".info-btn"), c.inst)
    li.querySelector(".p-head").after(instDetails(c.inst))
    const meta = li.querySelector(".p-meta")
    meta.replaceChildren(...programNodes(c), ...stateNodes(c.inst), document.createTextNode(` · ${c.quota}`))
    if (c.inst.doubtful) meta.title = DOUBTFUL_HINT
    paintCutoff(li.querySelector(".cutoff"), c)
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
  li.querySelector(".p-also-text").textContent = `Also in your plan: ${list}${elsewhere.length > 3 ? ` +${elsewhere.length - 3}` : ""}`
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
  state.editedThisVisit = true
  track("edited-plan")
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
  track("reordered-plan")
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
  el.title = text
  el.style.color = error ? "var(--danger)" : ""
  root.classList.toggle("busy", /…$/.test(text))
  root.classList.toggle("sync-error", error)
}

function savedWhen(date) {
  const now = new Date()
  if (date.toDateString() === now.toDateString()) return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  return date.toLocaleDateString([], { day: "numeric", month: "short", ...(date.getFullYear() === now.getFullYear() ? {} : { year: "numeric" }) })
}

function timeNow() {
  return savedWhen(new Date())
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
    setStatus(`On this device only · ${timeNow()}`)
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
  if (!state.dirty) catchUp()
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
      offerChoice(server, "Your plan was changed on another device while this one had unsynced edits.")
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

function offerChoice(server, message, { deviceLabel = "Keep this device's plan", accountLabel = "Use my account's plan", devicePicks = state.picks, onDone } = {}) {
  state.conflict = true
  clearTimeout(state.saveTimer)
  const box = $("#adopt")
  $("#adopt-text").textContent = `${message} This device: ${devicePicks.length} choices. Account: ${server.picks.length} choices.`
  $("#adopt-device").textContent = deviceLabel
  $("#adopt-account").textContent = accountLabel
  box.hidden = false
  setStatus("Choose which plan to keep", true)

  const finish = () => {
    box.hidden = true
    state.conflict = false
    onDone?.()
    catchUp()
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

async function catchUp({ force = false } = {}) {
  const busy = () => !synced() || state.revision === null || state.saving || state.dirty || state.conflict
  if (busy() || !(force || state.remoteRevision > state.revision)) return
  const server = await api(config.listUrl).catch(() => null)
  if (!server || busy() || server.revision <= state.revision) return
  state.revision = server.revision
  setPicks(server.picks)
  writeCache()
  rerender()
  setStatus(`Synced ${timeNow()}`)
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
    setStatus(`Synced ${timeNow()}`)
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
      offerChoice(server, "You made a plan on this device before signing in, and your account already has one.", {
        deviceLabel: "Use the plan from before I signed in",
        accountLabel: "Keep my account's plan",
        devicePicks,
        onDone: clearDevice,
      })
    }
  }
}

function loadDevice() {
  const device = storage.get(deviceKey())
  setPicks(device?.picks || [])
  if (state.picks.length) track("opened-saved-plan")
  setStatus(device?.savedAt ? `On this device only · ${savedWhen(new Date(device.savedAt))}` : "On this device only, saves as you go")
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
  track("exported-csv")
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
  track("has-extension")
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
    ? `MCC's saved list matches your plan (${matched.length} choices).`
    : `MCC has ${portal.choices.length} saved choices${unknown ? `, ${unknown} not in this catalog and left out` : ""}. Replace your plan (${state.picks.length} choices) with MCC's?`
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
  track("imported-from-mcc")
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
  track("used-filters")
  if (on) track(`filter/${name}`)
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

let sheetOpener = null

function openSheet(opener = $("#filters-open")) {
  sheetOpener = opener
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
  const visible = (el) => el?.isConnected && el.offsetParent
  const target = [sheetOpener, $("#map-legend [data-action=add-rank]"), $("#map-card [data-action]"), $("#map-subject [aria-checked=true]"), $("#filters-open")].find(visible)
  sheetOpener = null
  target?.focus()
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

const phoneLayout = () => matchMedia("(max-width: 900px)").matches

function showTab(name) {
  const pane = name === "map" ? "catalog" : name
  for (const btn of document.querySelectorAll(".tabs button")) btn.classList.toggle("active", btn.dataset.tab === name)
  for (const el of document.querySelectorAll(".pane")) el.classList.toggle("active", el.dataset.pane === pane)
  if (name === "map" && state.catalogView !== "map") setCatalogView("map")
  else if (name === "catalog" && state.catalogView === "map" && phoneLayout()) setCatalogView("list")
  else if (pane === "catalog" && state.catalogView === "map") catalogMap?.resize()
}

function toggleDetails(e) {
  const btn = e.target.closest(".info-btn")
  if (!btn?.dataset.code) return
  e.stopPropagation()
  const code = btn.dataset.code
  const open = !state.openDetails.has(code)
  open ? state.openDetails.add(code) : state.openDetails.delete(code)
  for (const box of document.querySelectorAll(`.inst-details[data-code="${CSS.escape(code)}"]`)) box.hidden = !open
  for (const other of document.querySelectorAll(`.info-btn[data-code="${CSS.escape(code)}"]`)) other.setAttribute("aria-expanded", String(open))
  if (open) track("opened-official-name")
}

function bind() {
  document.addEventListener("click", toggleDetails, true)
  let debounce
  $("#q").addEventListener("input", () => {
    track("searched-catalog")
    clearTimeout(debounce)
    debounce = setTimeout(() => applyFilters(), 120)
  })
  $("#my-rank").addEventListener("input", (e) => {
    state.profile.rank = Number(e.target.value) || null
    profileChanged()
    track("entered-rank")
  })
  $("#my-pwd").addEventListener("change", (e) => {
    state.profile.pwd = e.target.checked
    profileChanged()
  })
  $("#my-category").addEventListener("click", (e) => {
    const chip = e.target.closest("[data-category]")
    if (!chip) return
    state.profile.category = chip.dataset.category
    profileChanged()
  })
  $("#f-hide").addEventListener("change", (e) => {
    saveFilters()
    applyFilters()
    if (e.target.checked) track("filter/hide-added")
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
    const input = e.target.closest("input[type=checkbox][data-facet]")
    if (input) toggleFacet(input.dataset.facet, input.value, input.checked)
  })
  $("#facets").addEventListener("click", (e) => {
    const groupChip = e.target.closest("button[data-group]")
    if (groupChip) {
      state.groupBy = groupChip.dataset.group
      state.expanded.clear()
      saveFilters()
      applyFilters()
      if (state.groupBy !== "none") track(`group-by/${state.groupBy}`)
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

  for (const list of ["#results", "#picks", "#map-results"]) {
    $(list).addEventListener("click", (e) => {
      const btn = e.target.closest(".contact-btn")
      if (!btn) return
      e.stopPropagation()
      const choice = btn.dataset.code ? state.choices.find((c) => c.inst.code === btn.dataset.code) : state.byId.get(Number(btn.closest("li[data-id]").dataset.id))
      openContact(choice)
    }, true)
  }
  $("#contact-close").addEventListener("click", closeContact)

  const bindResultClicks = (list, groupsFor, rerender) => list.addEventListener("click", (e) => {
    const group = e.target.closest("li.group")
    if (group && e.target.closest(".g-more")) {
      state.expanded.has(group.dataset.group) ? state.expanded.delete(group.dataset.group) : state.expanded.add(group.dataset.group)
      rerender()
      return
    }
    if (group && e.target.closest(".g-addall")) {
      const items = groupsFor().find((g) => g.key === group.dataset.group)?.items || []
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
  bindResultClicks($("#results"), () => groupsOf(state.filtered), renderResults)
  bindResultClicks($("#map-results"), mapPanelGroups, renderMapPanel)
  $("#catalog-view").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-view]")
    if (btn && btn.dataset.view !== state.catalogView) setCatalogView(btn.dataset.view)
  })
  $("#map-panel-close").addEventListener("click", () => {
    state.mapPoint = null
    renderMapResults()
  })
  $("#map-subject").addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-subject]")
    if (btn) setMapSubject(btn.dataset.subject)
  })
  $("#map-lens").addEventListener("change", (e) => {
    state.mapLens = e.target.checked
    storage.set(mapLensKey(), state.mapLens)
    track(`map/odds/${state.mapLens ? "on" : "off"}`)
    renderMapResults()
  })
  $("#map-depth-input").addEventListener("input", (e) => {
    const depth = Number(e.target.value)
    state.planDepth = depth >= state.picks.length ? null : depth
    renderMapResults()
  })
  for (const box of ["#map-card", "#map-legend"]) {
    $(box).addEventListener("click", (e) => {
      const btn = e.target.closest("button[data-action]")
      if (btn) mapCardAction(btn.dataset.action, btn)
    })
  }
  $("#map-results").addEventListener("click", (e) => {
    const show = e.target.closest(".map-plan-show")
    if (!show) return
    const id = Number(show.closest("li[data-id]").dataset.id)
    showTab("order")
    setOrderView("ranked")
    state.openPick = id
    renderPicks()
    flash(id)
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
    track("added-note")
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
  document.addEventListener("choice-filler:usage", receiveExtensionUsage)
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
      setStatus("Choose which plan to keep before signing out.", true)
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

  window.addEventListener("load", sendUsage)
  document.addEventListener("visibilitychange", trackPlanSize)
  window.addEventListener("online", () => {
    sendUsage()
    if (synced() && state.dirty && !state.conflict) save()
    else catchUp({ force: true })
  })
  const streamSource = document.querySelector("turbo-cable-stream-source")
  if (streamSource) {
    new MutationObserver(() => {
      if (streamSource.hasAttribute("connected")) catchUp({ force: true })
    }).observe(streamSource, { attributes: true, attributeFilter: ["connected"] })
  }
  window.addEventListener("offline", () => setStatus(synced() ? "Offline — changes are saved on this device" : "Offline — on this device only"))
  window.addEventListener("beforeunload", (e) => {
    if (synced() && (state.saving || (state.dirty && navigator.onLine))) e.preventDefault()
  })
}

const ROUND_LABELS = { R1: "R1", R2: "R2", R3: "R3", STRAY: "Stray", SPSTRAY: "Sp. stray" }
const ROUND_ORDER = ["R1", "R2", "R3", "STRAY", "SPSTRAY"]
const MAIN_ROUNDS = ["R1", "R2", "R3"]
const CUTOFF_CAVEAT = "Calculated by this tool from MCC's published allotment results, not an official MCC figure. Seats and candidates change every year, some seats could not be matched, and labels are rough guides, not predictions."
const profileKey = () => `planner:${config.counselling}:profile`
const rankFormat = new Intl.NumberFormat("en-IN")

function eligibleCategories() {
  const base = state.profile.category === "Open" ? ["Open"] : ["Open", state.profile.category]
  return state.profile.pwd ? [...base, ...base.map((category) => `${category} PwD`)] : base
}

function eligibleLabel() {
  const base = state.profile.category === "Open" ? "Open" : `Open/${state.profile.category}`
  return state.profile.pwd ? `${base} incl. PwD` : base
}

function cutoffYears(c) {
  const rows = state.cutoffs?.[`${c.inst.code}|${c.brcd}|${c.quota}`]
  if (!rows) return []
  const eligible = new Set(eligibleCategories())
  const byYear = new Map()
  for (const [year, round, category, rank] of rows) {
    if (!eligible.has(category)) continue
    const rounds = byYear.get(year) || new Map()
    rounds.set(round, Math.max(rounds.get(round) || 0, rank))
    byYear.set(year, rounds)
  }
  return [...byYear.entries()].sort((a, b) => b[0] - a[0]).map(([year, rounds]) => {
    let deepest = 0
    const steps = ROUND_ORDER.filter((round) => rounds.has(round)).map((round) => {
      deepest = Math.max(deepest, rounds.get(round))
      return [round, deepest]
    })
    const main = MAIN_ROUNDS.filter((round) => rounds.has(round)).map((round) => rounds.get(round))
    return { year, steps, main: main.length ? Math.max(...main) : null }
  })
}

function chanceOf(rank, closing) {
  const ratio = rank / closing
  if (ratio <= 0.9) return ["Likely", "likely"]
  if (ratio <= 1.05) return ["Possible", "possible"]
  if (ratio <= 1.25) return ["Borderline", "borderline"]
  return ["Reach", "reach"]
}

function stepsText(steps) {
  return steps.map(([round, rank]) => `${ROUND_LABELS[round]} ${rankFormat.format(rank)}`).join(" · ")
}

function paintCutoff(el, c) {
  if (!el) return
  const years = cutoffYears(c)
  if (!years.length) {
    el.replaceChildren()
    el.title = ""
    return
  }
  const [latest] = years
  const nodes = [document.createTextNode(`${latest.year} closing · ${eligibleLabel()}: ${stepsText(latest.steps)}`)]
  const mains = years.map((year) => year.main).filter(Boolean)
  if (state.profile.rank && mains.length) {
    const [label, kind] = chanceOf(state.profile.rank, Math.min(...mains))
    const evidence = mains.length === 1 ? "Based on 1 year." : `Based on the tightest of ${mains.length} years.`
    nodes.push(make("span", { className: `chance chance-${kind}`, textContent: label, title: `${evidence} ${CUTOFF_CAVEAT}` }))
  }
  el.replaceChildren(...nodes)
  el.title = [...years.map((year) => `${year.year}: ${stepsText(year.steps)}`), "", "Each round shows the deepest rank allotted so far.", CUTOFF_CAVEAT].join("\n")
}

function repaintCutoffs() {
  for (const el of document.querySelectorAll("#results [data-id], #picks [data-id]")) {
    const c = state.byId.get(Number(el.dataset.id))
    if (c) paintCutoff(el.querySelector(".cutoff"), c)
  }
  if (state.catalogView === "map") renderMapResults()
}

function restoreProfile() {
  const saved = storage.get(profileKey()) || {}
  state.profile = { rank: Number(saved.rank) || null, category: ["Open", "OBC", "SC", "ST", "EWS"].includes(saved.category) ? saved.category : "Open", pwd: Boolean(saved.pwd) }
  $("#my-rank").value = state.profile.rank || ""
  $("#my-pwd").checked = state.profile.pwd
  paintProfile()
}

function paintProfile() {
  for (const chip of document.querySelectorAll("#my-category [data-category]")) {
    chip.setAttribute("aria-checked", String(chip.dataset.category === state.profile.category))
    chip.setAttribute("aria-pressed", String(chip.dataset.category === state.profile.category))
  }
}

function profileChanged() {
  chanceCache.clear()
  storage.set(profileKey(), state.profile)
  paintProfile()
  repaintCutoffs()
}

async function loadCutoffs() {
  try {
    state.cutoffs = await api(config.cutoffsUrl)
    chanceCache.clear()
    repaintCutoffs()
  } catch {
    state.cutoffsFailed = true
    if (state.catalogView === "map") renderMapResults()
  }
}

async function boot() {
  showTab("catalog")
  setStatus("Loading…")
  const catalog = await api(config.catalogUrl)
  buildCatalog(catalog)
  restoreProfile()
  bind()
  if (synced()) await loadSynced()
  else loadDevice()
  if (state.picks.length && (!synced() || config.ownList)) track(`saved-plan-size/${planSizeBucket(state.picks.length)}`)
  catchUp()
  renderPicks()
  applyFilters()
  let savedView = "ranked"
  try {
    savedView = localStorage.getItem(`planner:${config.counselling}:order-view`) || "ranked"
  } catch {}
  setOrderView(["ranked", "institute", "speciality"].includes(savedView) ? savedView : "ranked")
  state.mapSubject = storage.get(mapSubjectKey()) === "all" ? "all" : "plan"
  state.mapLens = storage.get(mapLensKey()) !== false
  if (storage.get(catalogViewKey()) === "map") setCatalogView("map")
  loadCutoffs()
}

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch(() => {})
}

if (root) boot().catch((err) => setStatus(`Failed to load: ${err.message}`, true))
