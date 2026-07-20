const CACHE_VERSION = "2026-07-09-20";
const PRECACHE_NAME = "nz-fieldworker-precache-" + CACHE_VERSION;
const RUNTIME_CACHE_NAME = "nz-fieldworker-runtime-" + CACHE_VERSION;
const OFFLINE_URL = "offline.html";
const MAX_RUNTIME_ENTRIES = 80;

const APP_SHELL = [
  OFFLINE_URL,
  "ICO.png",
  "style.css",
  "reference_date.js",
  "download_feedback.js",
  "live_nest_leaflet.js",
  "pwa_install.js",
  "manifest.webmanifest",
  "icons/icon-192.png",
  "icons/icon-512.png",
  "help/intro.html",
  "help/gps.html",
  "help/enter_data.html",
  "help/database.html"
];

const PRECACHE_URLS = new Set(
  APP_SHELL.map(function(url) {
    return new URL(url, self.registration.scope).href;
  })
);

const STATIC_DESTINATIONS = new Set([
  "font",
  "image",
  "manifest",
  "script",
  "style"
]);

function isCacheableResponse(response) {
  return response && response.ok && response.type === "basic";
}

async function precacheAppShell() {
  const cache = await caches.open(PRECACHE_NAME);

  await Promise.all(
    APP_SHELL.map(async function(url) {
      const request = new Request(url, { cache: "reload" });

      try {
        const response = await fetch(request);

        if (!isCacheableResponse(response)) {
          throw new Error("Unexpected response while caching " + url);
        }

        await cache.put(url, response);
      } catch (error) {
        if (url === OFFLINE_URL) {
          throw error;
        }

        console.warn("[service-worker] Skipped optional app-shell asset:", url, error);
      }
    })
  );
}

async function cleanupOldCaches() {
  const expectedCaches = new Set([PRECACHE_NAME, RUNTIME_CACHE_NAME]);
  const keys = await caches.keys();

  await Promise.all(
    keys
      .filter(function(key) {
        return key.indexOf("nz-fieldworker-") === 0 && !expectedCaches.has(key);
      })
      .map(function(key) {
        return caches.delete(key);
      })
  );
}

async function enableNavigationPreload() {
  if (self.registration.navigationPreload) {
    try {
      await self.registration.navigationPreload.enable();
    } catch (error) {
      console.warn("[service-worker] Navigation preload was not enabled:", error);
    }
  }
}

async function trimCache(cacheName, maxEntries) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();

  if (keys.length <= maxEntries) {
    return;
  }

  await Promise.all(
    keys.slice(0, keys.length - maxEntries).map(function(request) {
      return cache.delete(request);
    })
  );
}

async function putInRuntimeCache(request, response) {
  if (!isCacheableResponse(response)) {
    return;
  }

  const cache = await caches.open(RUNTIME_CACHE_NAME);
  await cache.put(request, response);
  await trimCache(RUNTIME_CACHE_NAME, MAX_RUNTIME_ENTRIES);
}

async function putInBestCache(request, response) {
  if (!isCacheableResponse(response)) {
    return;
  }

  if (PRECACHE_URLS.has(request.url)) {
    const cache = await caches.open(PRECACHE_NAME);
    await cache.put(request, response);
    return;
  }

  await putInRuntimeCache(request, response);
}

async function matchBestCache(request) {
  if (PRECACHE_URLS.has(request.url)) {
    const cache = await caches.open(PRECACHE_NAME);
    return cache.match(request);
  }

  const cache = await caches.open(RUNTIME_CACHE_NAME);
  return cache.match(request);
}

function shouldHandleRequest(request) {
  if (request.method !== "GET") {
    return false;
  }

  const url = new URL(request.url);
  return url.origin === self.location.origin;
}

function isStaticRequest(request) {
  if (PRECACHE_URLS.has(request.url)) {
    return true;
  }

  return STATIC_DESTINATIONS.has(request.destination);
}

async function networkFirstNavigation(event) {
  try {
    const preloadResponse = await event.preloadResponse;

    if (preloadResponse) {
      return preloadResponse;
    }

    return await fetch(event.request);
  } catch (error) {
    const offlineResponse = await caches.match(OFFLINE_URL);

    if (offlineResponse) {
      return offlineResponse;
    }

    return new Response("Fieldworker is offline and the offline page is unavailable.", {
      headers: { "Content-Type": "text/plain; charset=utf-8" },
      status: 503
    });
  }
}

async function staleWhileRevalidate(request, event) {
  const cachedResponse = await matchBestCache(request);

  const networkResponsePromise = fetch(request)
    .then(function(response) {
      if (isCacheableResponse(response)) {
        event.waitUntil(putInBestCache(request, response.clone()));
      }

      return response;
    })
    .catch(function() {
      return null;
    });

  if (cachedResponse) {
    return cachedResponse;
  }

  const networkResponse = await networkResponsePromise;

  if (networkResponse) {
    return networkResponse;
  }

  return new Response("Network request failed.", {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
    status: 503
  });
}

self.addEventListener("install", function(event) {
  event.waitUntil(
    precacheAppShell().then(function() {
      return self.skipWaiting();
    })
  );
});

self.addEventListener("activate", function(event) {
  event.waitUntil(
    Promise.all([
      cleanupOldCaches(),
      enableNavigationPreload()
    ]).then(function() {
      return self.clients.claim();
    })
  );
});

self.addEventListener("message", function(event) {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

self.addEventListener("fetch", function(event) {
  if (!shouldHandleRequest(event.request)) {
    return;
  }

  if (event.request.mode === "navigate") {
    event.respondWith(networkFirstNavigation(event));
    return;
  }

  if (isStaticRequest(event.request)) {
    event.respondWith(staleWhileRevalidate(event.request, event));
  }
});
