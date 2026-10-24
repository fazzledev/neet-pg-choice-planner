import * as L from "leaflet"

const ATTRIBUTION = 'Boundaries: <a href="https://github.com/datameet/maps">DataMeet</a> (CC BY 4.0) · Places: &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, <a href="https://www.geonames.org">GeoNames</a>'
const MAX_ZOOM = 9
const LABEL_SIZE = 11
const BIG_CITIES = [
  ["Delhi", 28.61, 77.21],
  ["Mumbai", 19.08, 72.88],
  ["Kolkata", 22.57, 88.36],
  ["Chennai", 13.08, 80.27],
  ["Bengaluru", 12.97, 77.59],
  ["Hyderabad", 17.39, 78.49],
  ["Ahmedabad", 23.02, 72.57],
  ["Pune", 18.52, 73.86],
  ["Jaipur", 26.91, 75.79],
  ["Lucknow", 26.85, 80.95],
  ["Patna", 25.59, 85.14],
  ["Bhopal", 23.26, 77.41],
  ["Guwahati", 26.14, 91.74],
  ["Bhubaneswar", 20.3, 85.82],
  ["Thiruvananthapuram", 8.52, 76.94],
  ["Chandigarh", 30.73, 76.78],
  ["Srinagar", 34.08, 74.8],
  ["Raipur", 21.25, 81.63],
]

export function createMap(el, { onSelect, shape }) {
  const map = L.map(el, { preferCanvas: true, zoomSnap: 0.25, maxZoom: MAX_ZOOM, attributionControl: false })
  L.control.attribution({ prefix: '<a href="https://leafletjs.com">Leaflet</a>' }).addAttribution(ATTRIBUTION).addTo(map)
  const dark = matchMedia("(prefers-color-scheme: dark)")
  const color = (name) => getComputedStyle(el).getPropertyValue(name).trim()

  map.createPane("land").style.zIndex = 250
  const states = L.geoJSON(shape, { pane: "land", interactive: false, renderer: L.svg({ pane: "land", padding: 0.5 }) }).addTo(map)
  const india = states.getBounds()
  const paintStates = () => states.setStyle({ color: color("--border"), weight: 1, fillColor: color("--surface"), fillOpacity: 1 })
  paintStates()
  const fitIndia = () => {
    map.options.minZoom = 0
    map.setMinZoom(map.getBoundsZoom(india))
  }
  map.fitBounds(india)
  fitIndia()
  map.setMaxBounds(india.pad(0.15))
  map.on("resize", fitIndia)

  const pins = L.layerGroup().addTo(map)
  let selected = null
  let last = []

  const labels = L.DomUtil.create("div", "map-labels", el)
  const measure = document.createElement("canvas").getContext("2d")
  const widths = new Map()
  document.fonts?.addEventListener("loadingdone", () => {
    widths.clear()
    placeLabels()
  })

  function textWidth(text) {
    if (!widths.has(text)) {
      measure.font = `600 ${LABEL_SIZE}px ${getComputedStyle(el).getPropertyValue("--font-body")}`
      widths.set(text, measure.measureText(text.toUpperCase()).width + text.length * LABEL_SIZE * 0.02 + 2)
    }
    return widths.get(text)
  }

  function nearPin(lat, lng) {
    const at = map.latLngToContainerPoint([lat, lng])
    return last.some((p) => at.distanceTo(map.latLngToContainerPoint([p.lat, p.lng])) < p.radius + 8)
  }

  function placeLabels() {
    const size = map.getSize()
    const taken = []
    const placed = new Set()
    const nodes = []
    const free = (box) => box.x1 >= 0 && box.y1 >= 0 && box.x2 <= size.x && box.y2 <= size.y && !taken.some((t) => box.x1 < t.x2 && box.x2 > t.x1 && box.y1 < t.y2 && box.y2 > t.y1)
    const place = (name, lat, lng, gap, className) => {
      const at = map.latLngToContainerPoint([lat, lng])
      const width = textWidth(name)
      const top = at.y - LABEL_SIZE / 2 - 1
      for (const left of [at.x + gap, at.x - gap - width]) {
        const box = { x1: left - 2, y1: top - 1, x2: left + width + 2, y2: top + LABEL_SIZE + 3 }
        if (!free(box)) continue
        taken.push(box)
        placed.add(name.toLowerCase())
        const node = document.createElement("span")
        node.className = className
        node.textContent = name
        node.style.transform = `translate(${Math.round(left)}px, ${Math.round(top)}px)`
        nodes.push(node)
        return
      }
    }
    const ranked = [...last].sort((a, b) => (b.key === selected) - (a.key === selected) || b.institutes.size - a.institutes.size)
    for (const point of ranked) place(point.city, point.lat, point.lng, point.radius + 4, "map-label")
    const named = last.map((p) => p.city.toLowerCase())
    for (const [name, lat, lng] of BIG_CITIES) {
      if (!placed.has(name.toLowerCase()) && !named.some((city) => city.includes(name.toLowerCase())) && !nearPin(lat, lng)) place(name, lat, lng, 4, "map-label map-label-faint")
    }
    labels.replaceChildren(...nodes)
  }

  let frame = null
  const placeSoon = () => {
    frame ??= requestAnimationFrame(() => {
      frame = null
      placeLabels()
    })
  }
  map.on("zoomstart", () => labels.replaceChildren())
  map.on("zoomend moveend resize", placeLabels)
  map.on("move", placeSoon)

  function draw() {
    pins.clearLayers()
    for (const point of [...last].sort((a, b) => (a.key === selected) - (b.key === selected))) {
      const on = point.key === selected
      const pin = L.circleMarker([point.lat, point.lng], {
        radius: point.radius + (on ? 3 : 0),
        color: on ? color("--text") : color("--accent"),
        weight: on ? 3 : 1,
        fillColor: point.picked ? color("--accent") : color("--accent-soft"),
        fillOpacity: 0.95,
      })
      pin.bindTooltip(point.label, { direction: "top", offset: [0, -point.radius] })
      pin.on("click", () => onSelect(point.key))
      pins.addLayer(pin)
    }
    placeLabels()
  }

  dark.addEventListener("change", () => {
    paintStates()
    draw()
  })

  return {
    show(points, { fit = false, selected: key = null } = {}) {
      last = points
      selected = key
      draw()
      if (!fit) return
      if (points.length) map.fitBounds(L.latLngBounds(points.map((p) => [p.lat, p.lng])).pad(0.2), { maxZoom: 7 })
      else map.fitBounds(india)
    },
    reveal(key) {
      const point = last.find((p) => p.key === key)
      if (point && !map.getBounds().pad(-0.1).contains([point.lat, point.lng])) map.panTo([point.lat, point.lng])
    },
    resize() {
      map.invalidateSize()
      fitIndia()
    },
  }
}
