const CACHE_NAME = "nz-fieldworker-v2";
const APP_SHELL = [
  "./",
  "offline.html",
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
  "help/gps.md",
  "help/enter_data.md",
  "help/database.md"
];

self.addEventListener("install", function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
      return cache.addAll(APP_SHELL);
    })
  );
});

self.addEventListener("activate", function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys
          .filter(function(key) {
            return key !== CACHE_NAME;
          })
          .map(function(key) {
            return caches.delete(key);
          })
      );
    })
  );
});

self.addEventListener("fetch", function(event) {
  if (event.request.method !== "GET") {
    return;
  }

  if (event.request.mode === "navigate") {
    event.respondWith(
      fetch(event.request).catch(function() {
        return caches.match("offline.html");
      })
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(function(cached) {
      return cached || fetch(event.request);
    })
  );
});
