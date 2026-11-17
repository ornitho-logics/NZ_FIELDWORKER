// Release identity is in the script URL; manifest id, start_url, and scope stay stable.
const BUILD_ID = new URL(self.location.href).searchParams.get("build") || "development-v2";
const CACHE_PREFIX = "nz-fieldworker-offline-" + encodeURIComponent(self.registration.scope) + "-";
const CACHE_NAME = CACHE_PREFIX + BUILD_ID;
const OFFLINE_URL = new URL("offline.html", self.registration.scope).href;

async function cleanupOldCaches() {
  for (const key of await caches.keys()) {
    if (key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME) {
      await caches.delete(key);
    } else if (/^nz-fieldworker-(precache|runtime)-/.test(key)) {
      // Legacy caches were origin-wide. Never delete a cache used by another app.
      const requests = await (await caches.open(key)).keys();
      if (requests.length && requests.every(function(request) {
        return request.url.startsWith(self.registration.scope);
      })) await caches.delete(key);
    }
  }
}

self.addEventListener("install", function(event) {
  event.waitUntil((async function() {
    const response = await fetch(OFFLINE_URL, { cache: "reload" });
    if (!response.ok || response.type !== "basic") throw new Error("Offline page unavailable");
    await (await caches.open(CACHE_NAME)).put(OFFLINE_URL, response);
    // Wait for existing windows to close or for an explicit user update request.
  })());
});

self.addEventListener("activate", function(event) {
  event.waitUntil((async function() {
    await cleanupOldCaches();
    await self.clients.claim();
  })());
});

self.addEventListener("message", function(event) {
  if (event.data && event.data.type === "FIELDWORKER_APPLY_UPDATE" &&
      event.data.build === new URL(self.location.href).searchParams.get("build")) {
    event.waitUntil(self.skipWaiting());
  }
});

self.addEventListener("fetch", function(event) {
  // Never cache Shiny HTML, sessions, data, downloads, plots, scripts, or manifests.
  if (event.request.method !== "GET" || event.request.mode !== "navigate" ||
      !event.request.url.startsWith(self.registration.scope)) return;
  event.respondWith((async function() {
    try {
      return await fetch(event.request, { cache: "no-store" });
    } catch (error) {
      const offline = await (await caches.open(CACHE_NAME)).match(OFFLINE_URL);
      return offline || new Response("Fieldworker needs a connection. Please try again.", {
        status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" }
      });
    }
  })());
});
