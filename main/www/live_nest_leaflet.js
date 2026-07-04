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
