(function() {
  "use strict";

  function initialize() {
    var output = document.getElementById("quick_search_results");
    if (!output) return;

    var watchId = null;
    var generation = 0;
    var position = null;
    var connected = true;
    var maxAge = 15000;

    function coordinate(value, limit) {
      if (value === null || String(value).trim() === "") return null;
      var number = Number(value);
      return Number.isFinite(number) && Math.abs(number) <= limit ? number : null;
    }

    function target() {
      var cell = output.querySelector(".quick-search-distance");
      if (!cell || document.hidden || !cell.getClientRects().length) return null;
      var lat = coordinate(cell.getAttribute("data-nest-lat"), 90);
      var lon = coordinate(cell.getAttribute("data-nest-lon"), 180);
      return lat === null || lon === null ? null : {cell: cell, lat: lat, lon: lon};
    }

    function draw() {
      var nest = target();
      if (!nest) return;
      var label = "—";
      if (position && Date.now() - position.timestamp <= maxAge) {
        var lat = coordinate(position.coords.latitude, 90);
        var lon = coordinate(position.coords.longitude, 180);
        if (lat !== null && lon !== null) {
          var radians = Math.PI / 180;
          var deltaLat = (nest.lat - lat) * radians;
          var deltaLon = (nest.lon - lon) * radians;
          var a = Math.pow(Math.sin(deltaLat / 2), 2) +
            Math.cos(lat * radians) * Math.cos(nest.lat * radians) *
            Math.pow(Math.sin(deltaLon / 2), 2);
          var meters = 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, a))));
          label = meters < 1000 ? Math.round(meters) + " m" : (meters / 1000).toFixed(2) + " km";
        }
      }
      if (nest.cell.textContent !== label) nest.cell.textContent = label;
    }

    function stop() {
      generation += 1;
      if (watchId !== null) navigator.geolocation.clearWatch(watchId);
      watchId = null;
      position = null;
      var cell = output.querySelector(".quick-search-distance");
      if (cell && cell.textContent !== "—") cell.textContent = "—";
    }

    function refresh() {
      if (!connected || !target() || !navigator.geolocation) {
        if (watchId !== null) stop();
        return;
      }
      draw();
      if (watchId !== null) return;
      var request = ++generation;
      try {
        watchId = navigator.geolocation.watchPosition(function(fix) {
          if (request !== generation) return;
          position = fix;
          draw();
        }, function() {
          if (request !== generation) return;
          position = null;
          draw();
        }, {enableHighAccuracy: true, maximumAge: 2000, timeout: 15000});
      } catch (error) {
        stop();
      }
    }

    // Output replacement and tab changes must not leave an old nest distance
    // or a background location watch running. Device coordinates stay here.
    new MutationObserver(refresh).observe(output, {childList: true, subtree: true});
    document.addEventListener("visibilitychange", refresh);
    window.addEventListener("pagehide", stop);
    window.addEventListener("pageshow", refresh);
    if (window.jQuery) {
      window.jQuery(document).on("shown.bs.tab hidden.bs.tab", refresh);
      window.jQuery(document).on("shiny:disconnected", function() {
        connected = false;
        stop();
      });
      window.jQuery(document).on("shiny:connected", function() {
        connected = true;
        refresh();
      });
    }
    // Expire stale fixes even when the browser stops delivering positions.
    window.setInterval(draw, 1000);
    refresh();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize);
  } else {
    initialize();
  }
})();
