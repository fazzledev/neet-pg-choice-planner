const CACHE = "planner-v1"
const SHELL = ["/"]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  )
})

const cacheable = (url) => url.pathname === "/" || url.pathname.startsWith("/assets/") || url.pathname.startsWith("/catalogs/") || url.pathname === "/manifest.json" || url.pathname.startsWith("/icon")

async function networkFirst(request) {
  const cache = await caches.open(CACHE)
  try {
    const response = await fetch(request)
    if (response.ok) cache.put(request, response.clone())
    return response
  } catch (error) {
    const cached = await cache.match(request, { ignoreSearch: true })
    if (cached) return cached
    throw error
  }
}

async function cacheFirst(request) {
  const cache = await caches.open(CACHE)
  const cached = await cache.match(request)
  if (cached) return cached
  const response = await fetch(request)
  if (response.ok) cache.put(request, response.clone())
  return response
}

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url)
  if (event.request.method !== "GET" || url.origin !== self.location.origin || !cacheable(url)) return
  event.respondWith(url.pathname.startsWith("/assets/") ? cacheFirst(event.request) : networkFirst(event.request))
})
