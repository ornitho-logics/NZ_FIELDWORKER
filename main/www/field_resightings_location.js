(function() {
  "use strict";

  function initialize() {
    var output = document.getElementById("field_resightings_results");
    if (!output) return;

    var watchId = null;
    var generation = 0;
    var position = null;
    var connected = true;
    var maxAge = 15000;
    var saveHandlerRegistered = false;
    var browserId = null;
    var pendingSave = null;
    var denied = false;
    var pageActive = true;
    var displayCell = null;

    function getBrowserId() {
      if (browserId) return browserId;
      var key = "fieldworker.browser_id";
      var validId = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      try {
        var stored = window.localStorage.getItem(key);
        if (validId.test(stored)) browserId = stored.toLowerCase();
      } catch (error) {
        // Storage may be blocked; retain the ID for this page session.
      }
      if (!browserId) {
        if (!window.crypto || typeof window.crypto.randomUUID !== "function") return null;
        try {
          browserId = window.crypto.randomUUID();
        } catch (error) {
          return null;
        }
        try {
          window.localStorage.setItem(key, browserId);
        } catch (error) {
          // Saving a sighting can still use this session's generated ID.
        }
      }
      return browserId;
    }

    function saveForm() {
      return output.querySelector(".field-resightings-save-form");
    }

    function visible(element) {
      return element && pageActive && !document.hidden && element.getClientRects().length;
    }

    function registerSaveHandler() {
      if (saveHandlerRegistered || !window.Shiny) return;
      window.Shiny.addCustomMessageHandler("field_resightings_save_result", function(result) {
        var form = saveForm();
        if (!form || form.getAttribute("data-search-token") !== result.token) return;
        form.querySelector(".field-resightings-save-status").textContent = result.message;
        var button = form.querySelector("button[type=submit]");
        button.disabled = result.saved;
        form.querySelector("fieldset").disabled = result.saved;
        button.textContent = result.saved ? "Saved" : "Save resighting";
        form.setAttribute("data-saved", result.saved ? "true" : "false");
      });
      saveHandlerRegistered = true;
    }

    function coordinate(value, limit) {
      if (value === null || String(value).trim() === "") return null;
      var number = Number(value);
      return Number.isFinite(number) && Math.abs(number) <= limit ? number : null;
    }

    function target() {
      var cell = output.querySelector(".field-resightings-distance");
      if (!visible(cell)) return null;
      var lat = coordinate(cell.getAttribute("data-nest-lat"), 90);
      var lon = coordinate(cell.getAttribute("data-nest-lon"), 180);
      return lat === null || lon === null ? null : {cell: cell, lat: lat, lon: lon};
    }

    function draw() {
      var nest = target();
      if (!nest) return;
      var label = "—";
      var fix = locationPayload(position);
      if (fix) {
        var lat = fix.latitude;
        var lon = fix.longitude;
        var radians = Math.PI / 180;
        var deltaLat = (nest.lat - lat) * radians;
        var deltaLon = (nest.lon - lon) * radians;
        var a = Math.pow(Math.sin(deltaLat / 2), 2) +
          Math.cos(lat * radians) * Math.cos(nest.lat * radians) *
          Math.pow(Math.sin(deltaLon / 2), 2);
        var meters = 6371000 * 2 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, a))));
        label = meters < 1000 ? Math.round(meters) + " m" : (meters / 1000).toFixed(2) + " km";
      }
      if (nest.cell.textContent !== label) nest.cell.textContent = label;
    }

    function stop() {
      if (pendingSave) pendingSave.cancel();
      generation += 1;
      if (watchId !== null) navigator.geolocation.clearWatch(watchId);
      watchId = null;
      position = null;
      displayCell = null;
      var cell = output.querySelector(".field-resightings-distance");
      if (cell && cell.textContent !== "—") cell.textContent = "—";
    }

    function refresh() {
      if (pendingSave && pendingSave.form !== saveForm()) pendingSave.cancel();
      if (!connected || (!target() && !visible(saveForm())) || !navigator.geolocation) {
        stop();
        return;
      }
      var nest = target();
      if (nest && nest.cell !== displayCell) {
        displayCell = nest.cell;
        draw();
      }
      if (watchId !== null || denied) return;
      var request = ++generation;
      try {
        watchId = navigator.geolocation.watchPosition(function(fix) {
          if (request !== generation) return;
          remember(fix);
          if (pendingSave && locationPayload(position)) pendingSave.resolve(position);
        }, function(error) {
          if (request !== generation) return;
          if (error && error.code === 1) {
            denied = true;
            if (pendingSave) {
              pendingSave.form.querySelector(".field-resightings-save-status").textContent = "GPS unavailable.";
            }
            stop();
          } else if (!locationPayload(position)) {
            position = null;
            draw();
          }
        }, {enableHighAccuracy: true, maximumAge: 2000, timeout: 15000});
      } catch (error) {
        stop();
      }
    }

    function locationPayload(fix) {
      if (!fix || !fix.coords || !Number.isFinite(fix.timestamp) ||
          Date.now() - fix.timestamp > maxAge || fix.timestamp > Date.now() + 5000) return null;
      if (typeof fix.coords.latitude !== "number" || typeof fix.coords.longitude !== "number") return null;
      var lat = coordinate(fix.coords.latitude, 90);
      var lon = coordinate(fix.coords.longitude, 180);
      if (lat === null || lon === null) return null;
      var accuracy = fix.coords.accuracy;
      return {
        latitude: lat, longitude: lon, timestamp: fix.timestamp,
        accuracy: Number.isFinite(accuracy) && accuracy >= 0 ? accuracy : null
      };
    }

    function remember(fix) {
      if (locationPayload(fix) &&
          (!locationPayload(position) || fix.timestamp >= position.timestamp)) {
        position = fix;
      }
    }

    function updateBehaviours(form) {
      var selected = form.querySelector(".field-resightings-behaviour-selected");
      selected.replaceChildren();
      form.querySelectorAll('input[name="field_resightings_behav"]:checked').forEach(function(input) {
        var chip = document.createElement("button");
        var label = input.getAttribute("data-label");
        chip.type = "button";
        chip.className = "field-resightings-behaviour-chip";
        chip.setAttribute("data-behaviour", input.value);
        chip.setAttribute("aria-label", "Remove " + label);
        chip.textContent = label + " ×";
        selected.appendChild(chip);
      });
    }

    document.addEventListener("change", function(event) {
      if (event.target.matches('input[name="field_resightings_behav"]')) {
        updateBehaviours(event.target.closest(".field-resightings-save-form"));
      }
    });

    document.addEventListener("click", function(event) {
      var button = event.target.closest(
        ".field-resightings-behaviour-open, .field-resightings-behaviour-done, .field-resightings-behaviour-chip"
      );
      if (!button) return;
      var form = button.closest(".field-resightings-save-form");
      if (!form || form.querySelector("fieldset").disabled) return;
      var sheet = form.querySelector(".field-resightings-behaviour-sheet");
      if (button.classList.contains("field-resightings-behaviour-open")) {
        sheet.showModal();
      } else if (button.classList.contains("field-resightings-behaviour-done")) {
        sheet.close();
      } else {
        var code = button.getAttribute("data-behaviour");
        form.querySelectorAll('input[name="field_resightings_behav"]').forEach(function(input) {
          if (input.value === code) input.checked = false;
        });
        updateBehaviours(form);
      }
    });

    document.addEventListener("submit", function(event) {
      var form = event.target;
      if (!form.matches(".field-resightings-save-form")) return;
      event.preventDefault();
      var sheet = form.querySelector(".field-resightings-behaviour-sheet");
      if (sheet && sheet.open) {
        sheet.close();
        return;
      }
      var button = form.querySelector("button[type=submit]");
      if (button.disabled || !connected || !window.Shiny) return;
      var status = form.querySelector(".field-resightings-save-status");
      var behaviours = Array.from(form.querySelectorAll('input[name="field_resightings_behav"]:checked')).map(function(option) {
        return option.value;
      });
      if (!behaviours.length) {
        status.textContent = "Choose a behaviour.";
        return;
      }
      var combo = document.getElementById("field_resightings_combo").value;
      if (combo.trim().toUpperCase().replace("-", "") !== form.getAttribute("data-combo")) {
        status.textContent = "Search this combo first.";
        return;
      }
      var token = form.getAttribute("data-search-token");
      button.disabled = true;
      form.querySelector("fieldset").disabled = true;
      button.textContent = "Saving…";
      status.textContent = "";
      function reset() {
        button.disabled = false;
        form.querySelector("fieldset").disabled = false;
        button.textContent = "Save resighting";
      }
      var attempt = {
        form: form,
        timer: null,
        cancel: function() {
          window.clearTimeout(attempt.timer);
          if (pendingSave === attempt) pendingSave = null;
          reset();
        },
        resolve: send
      };
      pendingSave = attempt;
      function send(fix) {
        // Ignore callbacks from cancelled or completed saves.
        if (pendingSave !== attempt) return;
        if (!connected || !visible(form) || saveForm() !== form) {
          attempt.cancel();
          return;
        }
        remember(fix);
        var location = locationPayload(position);
        var id = getBrowserId();
        if (!location || !id) {
          attempt.cancel();
          status.textContent = !location ? "GPS unavailable." : "Browser ID unavailable.";
          return;
        }
        window.clearTimeout(attempt.timer);
        pendingSave = null;
        window.Shiny.setInputValue("field_resightings_save_request", {
          token: token, combo: combo, behaviours: behaviours, location: location,
          browser_id: id
        }, {priority: "event"});
      }
      if (locationPayload(position) || !navigator.geolocation) {
        send(position);
      } else {
        // The browser's GPS timeout excludes permission prompts. Bound the
        // pending save too, and let the background watch satisfy it sooner.
        attempt.timer = window.setTimeout(function() {send(null);}, 10000);
        denied = false;
        refresh();
        if (pendingSave !== attempt) return;
        try {
          navigator.geolocation.getCurrentPosition(send, function() {send(null);}, {
            enableHighAccuracy: true, maximumAge: 2000, timeout: 10000
          });
        } catch (error) {
          send(null);
        }
      }
    });

    // Output replacement and tab changes must not leave an old nest distance
    // or a background location watch running. Send coordinates only on Save.
    new MutationObserver(refresh).observe(output, {childList: true, subtree: true});
    document.addEventListener("visibilitychange", function() {
      if (!document.hidden) denied = false;
      refresh();
    });
    window.addEventListener("pagehide", function() {pageActive = false; stop();});
    window.addEventListener("pageshow", function() {pageActive = true; denied = false; refresh();});
    if (window.jQuery) {
      window.jQuery(document).on("shown.bs.tab hidden.bs.tab", function() {
        denied = false;
        refresh();
      });
      window.jQuery(document).on("shiny:disconnected", function() {
        connected = false;
        stop();
        var form = saveForm();
        if (form && form.getAttribute("data-saved") !== "true") {
          form.querySelector(".field-resightings-save-status").textContent = "Connection lost. Search again.";
          form.querySelector("button[type=submit]").disabled = true;
        }
      });
      window.jQuery(document).on("shiny:connected", function() {
        connected = true;
        registerSaveHandler();
        refresh();
      });
    }
    // Expire stale fixes even when the browser stops delivering positions.
    window.setInterval(draw, 5000);
    registerSaveHandler();
    refresh();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize);
  } else {
    initialize();
  }
})();
