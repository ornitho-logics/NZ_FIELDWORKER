window.liveNestLeafletMobileSizing = function(el, x) {
  var map = this;
  var mobileQuery = window.matchMedia("(max-width: 768px), (pointer: coarse)");

  function isNestMarker(layer) {
    return layer &&
      layer.options &&
      typeof layer.options.className === "string" &&
      layer.options.className.indexOf("nest-circle-marker") !== -1;
  }

  function applyNestMobileSizing() {
    var mobile = mobileQuery.matches;

    map.eachLayer(function(layer) {
      if (!isNestMarker(layer)) {
        return;
      }

      if (typeof layer.options.nestBaseRadius === "undefined") {
        layer.options.nestBaseRadius = layer.options.radius || 5;
      }

      if (typeof layer.options.nestBaseWeight === "undefined") {
        layer.options.nestBaseWeight = layer.options.weight || 1;
      }

      if (typeof layer.setRadius === "function") {
        layer.setRadius(
          mobile ?
            Math.max(layer.options.nestBaseRadius * 1.5, 8) :
            layer.options.nestBaseRadius
        );
      }

      if (typeof layer.setStyle === "function") {
        layer.setStyle({
          weight: mobile ?
            Math.max(layer.options.nestBaseWeight * 1.5, 2) :
            layer.options.nestBaseWeight
        });
      }
    });

    el.querySelectorAll(".nest-label").forEach(function(label) {
      if (!label.dataset.nestBaseFontSize) {
        label.dataset.nestBaseFontSize =
          parseFloat(label.style.fontSize) ||
          parseFloat(window.getComputedStyle(label).fontSize) ||
          12;
      }

      var baseFontSize = parseFloat(label.dataset.nestBaseFontSize);
      label.style.fontSize = (
        mobile ? Math.max(baseFontSize * 1.35, 16) : baseFontSize
      ) + "px";
    });
  }

  map.whenReady(function() {
    applyNestMobileSizing();
    setTimeout(applyNestMobileSizing, 0);
  });

  map.on("layeradd overlayadd zoomend moveend", applyNestMobileSizing);
  window.addEventListener("resize", applyNestMobileSizing);
};

window.liveNestLeafletGpsControl = function(el, x) {
  var map = this;
  var leaflet = window.L;

  if (!leaflet || !map || map._liveNestGpsControl) {
    return;
  }

  var locateButton = null;
  var followButton = null;
  var state = {
    accuracyCircle: null,
    following: false,
    marker: null,
    watchId: null
  };

  function hasGeolocation() {
    return typeof navigator !== "undefined" && !!navigator.geolocation;
  }

  function locationOptions(watching) {
    return {
      enableHighAccuracy: true,
      maximumAge: watching ? 2000 : 5000,
      timeout: watching ? 15000 : 10000
    };
  }

  function setBusy(button, busy) {
    leaflet.DomUtil[busy ? "addClass" : "removeClass"](
      button,
      "live-gps-busy"
    );
  }

  function setError(message) {
    [locateButton, followButton].forEach(function(button) {
      leaflet.DomUtil.addClass(button, "live-gps-error");
      button.title = message;
    });
  }

  function clearError() {
    leaflet.DomUtil.removeClass(locateButton, "live-gps-error");
    locateButton.title = "Show my GPS position";
    leaflet.DomUtil.removeClass(followButton, "live-gps-error");
    followButton.title = state.following ?
      "Stop following GPS position" :
      "Follow GPS position";
  }

  function setFollowActive(active) {
    state.following = active;

    leaflet.DomUtil[active ? "addClass" : "removeClass"](
      followButton,
      "live-gps-active"
    );
    followButton.setAttribute("aria-pressed", active ? "true" : "false");
    followButton.title = active ?
      "Stop following GPS position" :
      "Follow GPS position";
  }

  function positionPopup(position) {
    var coords = position.coords;
    var accuracy = Math.round(coords.accuracy || 0);
    var updated = new Date(position.timestamp).toLocaleTimeString();

    return [
      "<strong>Your GPS position</strong>",
      "Accuracy: " + accuracy + " m",
      "Updated: " + updated
    ].join("<br>");
  }

  function drawPosition(position, moveMap) {
    var coords = position.coords;
    var latlng = leaflet.latLng(coords.latitude, coords.longitude);
    var accuracy = Math.max(coords.accuracy || 0, 0);

    clearError();

    if (!state.accuracyCircle) {
      state.accuracyCircle = leaflet.circle(latlng, {
        className: "live-gps-accuracy",
        color: "#0f766e",
        fillColor: "#14b8a6",
        fillOpacity: 0.12,
        interactive: false,
        opacity: 0.55,
        radius: accuracy,
        weight: 1
      }).addTo(map);
    } else {
      state.accuracyCircle.setLatLng(latlng);
      state.accuracyCircle.setRadius(accuracy);
    }

    if (!state.marker) {
      state.marker = leaflet.circleMarker(latlng, {
        className: "live-gps-marker",
        color: "#0f766e",
        fillColor: "#14b8a6",
        fillOpacity: 0.92,
        radius: 7,
        weight: 2
      }).addTo(map);
    } else {
      state.marker.setLatLng(latlng);
    }

    state.marker.bindPopup(positionPopup(position));

    if (moveMap || state.following) {
      map.setView(latlng, Math.max(map.getZoom(), 17), {
        animate: true
      });
    }
  }

  function gpsErrorMessage(error) {
    if (error.code === error.PERMISSION_DENIED) {
      return "GPS permission was denied.";
    }

    if (error.code === error.POSITION_UNAVAILABLE) {
      return "GPS position is unavailable.";
    }

    if (error.code === error.TIMEOUT) {
      return "GPS request timed out.";
    }

    return "Could not get GPS position.";
  }

  function handleGpsError(error) {
    setBusy(locateButton, false);
    setBusy(followButton, false);
    stopFollow();
    setError(gpsErrorMessage(error));
  }

  function locateOnce() {
    if (!hasGeolocation()) {
      setError("GPS is unavailable in this browser.");
      return;
    }

    clearError();
    setBusy(locateButton, true);

    navigator.geolocation.getCurrentPosition(
      function(position) {
        setBusy(locateButton, false);
        drawPosition(position, true);
      },
      handleGpsError,
      locationOptions(false)
    );
  }

  function startFollow() {
    if (!hasGeolocation()) {
      setError("GPS is unavailable in this browser.");
      return;
    }

    clearError();
    setBusy(followButton, true);
    setFollowActive(true);

    state.watchId = navigator.geolocation.watchPosition(
      function(position) {
        setBusy(followButton, false);
        drawPosition(position, true);
      },
      handleGpsError,
      locationOptions(true)
    );
  }

  function stopFollow() {
    if (state.watchId !== null) {
      navigator.geolocation.clearWatch(state.watchId);
    }

    state.watchId = null;
    setBusy(followButton, false);
    setFollowActive(false);
  }

  function cleanup() {
    stopFollow();
    window.removeEventListener("beforeunload", cleanup);
  }

  function toggleFollow() {
    if (state.following) {
      stopFollow();
    } else {
      startFollow();
    }
  }

  function makeButton(container, className, label) {
    var button = leaflet.DomUtil.create(
      "a",
      "live-gps-button " + className,
      container
    );
    button.href = "#";
    button.title = label;
    button.setAttribute("aria-label", label);
    button.setAttribute("aria-pressed", "false");
    button.setAttribute("role", "button");

    var icon = leaflet.DomUtil.create("span", "live-gps-icon", button);
    icon.setAttribute("aria-hidden", "true");

    return button;
  }

  var GpsControl = leaflet.Control.extend({
    options: {
      position: "topright"
    },

    onAdd: function() {
      var container = leaflet.DomUtil.create(
        "div",
        "leaflet-bar live-gps-control"
      );

      locateButton = makeButton(
        container,
        "live-gps-locate",
        "Show my GPS position"
      );
      followButton = makeButton(
        container,
        "live-gps-follow",
        "Follow GPS position"
      );

      leaflet.DomEvent.disableClickPropagation(container);
      leaflet.DomEvent.disableScrollPropagation(container);

      leaflet.DomEvent
        .on(locateButton, "click", leaflet.DomEvent.stop)
        .on(locateButton, "click", locateOnce)
        .on(followButton, "click", leaflet.DomEvent.stop)
        .on(followButton, "click", toggleFollow);

      if (!hasGeolocation()) {
        setError("GPS is unavailable in this browser.");
        leaflet.DomUtil.addClass(container, "live-gps-unavailable");
      }

      return container;
    },

    onRemove: function() {
      cleanup();
    }
  });

  map._liveNestGpsControl = new GpsControl();
  map._liveNestGpsControl.addTo(map);
  map.on("unload", cleanup);
  window.addEventListener("beforeunload", cleanup);
};

window.liveNestLeafletRender = function(el, x) {
  window.liveNestLeafletMobileSizing.call(this, el, x);
  window.liveNestLeafletGpsControl.call(this, el, x);
};
