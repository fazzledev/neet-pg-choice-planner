import * as L from "leaflet"

const INDIA = [[6.5, 68], [35.7, 97.5]]
const TILES = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'

export function createMap(el, { onSelect }) {
  const dark = matchMedia("(prefers-color-scheme: dark)")
  const map = L.map(el, { preferCanvas: true, zoomSnap: 0.5, minZoom: 4, maxBounds: [[-5, 55], [45, 110]] })
  map.fitBounds(INDIA)
  L.tileLayer(TILES, { attribution: ATTRIBUTION, maxZoom: 18 }).addTo(map)

  const pins = L.layerGroup().addTo(map)
  let selected = null
  let last = []

  function draw() {
    const css = getComputedStyle(el)
    const color = (name) => css.getPropertyValue(name).trim()
    pins.clearLayers()
    for (const point of [...last].sort((a, b) => (a.key === selected) - (b.key === selected))) {
      const on = point.key === selected
      const pin = L.circleMarker([point.lat, point.lng], {
        radius: point.radius + (on ? 3 : 0),
        color: on ? color("--text") : color("--accent"),
        weight: on ? 3 : 1.5,
        fillColor: point.picked ? color("--accent") : color("--surface"),
        fillOpacity: 0.92,
      })
      pin.bindTooltip(point.label, { direction: "top", offset: [0, -point.radius] })
      pin.on("click", () => onSelect(point.key))
      pins.addLayer(pin)
    }
  }

  dark.addEventListener("change", draw)

  return {
    show(points, { fit = false } = {}) {
      last = points
      draw()
      if (!fit) return
      if (points.length) map.fitBounds(L.latLngBounds(points.map((p) => [p.lat, p.lng])).pad(0.15), { maxZoom: 11 })
      else map.fitBounds(INDIA)
    },
    select(key) {
      selected = key
      draw()
      const point = last.find((p) => p.key === key)
      if (point && !map.getBounds().pad(-0.1).contains([point.lat, point.lng])) map.panTo([point.lat, point.lng])
    },
    resize() {
      map.invalidateSize()
    },
  }
}
