import * as L from "leaflet"

const ATTRIBUTION = 'Boundaries: <a href="https://github.com/datameet/maps">DataMeet</a> (CC BY 4.0)'
const MAX_ZOOM = 9
const BIG_CITIES = [
  ["Delhi", 28.61, 77.21],
  ["Mumbai", 19.08, 72.88, "left"],
  ["Kolkata", 22.57, 88.36],
  ["Chennai", 13.08, 80.27, "right"],
  ["Bengaluru", 12.97, 77.59, "left"],
  ["Hyderabad", 17.39, 78.49],
  ["Ahmedabad", 23.02, 72.57],
  ["Pune", 18.52, 73.86, "right"],
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
  L.control.attribution({ prefix: false }).addAttribution(ATTRIBUTION).addTo(map)
  const dark = matchMedia("(prefers-color-scheme: dark)")
  const color = (name) => getComputedStyle(el).getPropertyValue(name).trim()

  map.createPane("land").style.zIndex = 250
  map.createPane("labels").style.zIndex = 450
  const states = L.geoJSON(shape, { pane: "land", interactive: false, renderer: L.svg({ pane: "land", padding: 0.5 }) }).addTo(map)
  const india = states.getBounds()
  const paintStates = () => states.setStyle({ color: color("--border"), weight: 1, fillColor: color("--surface"), fillOpacity: 1 })
  paintStates()
  map.fitBounds(india)
  map.setMinZoom(map.getZoom())
  map.setMaxBounds(india.pad(0.15))

  for (const [name, lat, lng, side = "below"] of BIG_CITIES) {
    L.marker([lat, lng], { pane: "labels", interactive: false, keyboard: false, icon: L.divIcon({ className: `map-city map-city-${side}`, html: `<span>${name}</span>`, iconSize: null }) }).addTo(map)
  }

  const pins = L.layerGroup().addTo(map)
  let selected = null
  let last = []

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
  }

  dark.addEventListener("change", () => {
    paintStates()
    draw()
  })

  return {
    show(points, { fit = false } = {}) {
      last = points
      draw()
      if (!fit) return
      if (points.length) map.fitBounds(L.latLngBounds(points.map((p) => [p.lat, p.lng])).pad(0.2), { maxZoom: 7 })
      else map.fitBounds(india)
    },
    select(key, { pan = false } = {}) {
      selected = key
      draw()
      const point = last.find((p) => p.key === key)
      if (pan && point && !map.getBounds().pad(-0.1).contains([point.lat, point.lng])) map.panTo([point.lat, point.lng])
    },
    resize() {
      map.invalidateSize()
      map.setMinZoom(map.getBoundsZoom(india))
    },
  }
}
