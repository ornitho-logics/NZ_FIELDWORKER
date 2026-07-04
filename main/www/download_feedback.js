(function() {
  var fallbackMs = 45000;

  function visibleButton(downloadId) {
    return document.getElementById(downloadId + "_bttn") ||
      document.getElementById(downloadId);
  }

  function downloadId(el) {
    if (el.classList.contains("shiny-download-link")) {
      return el.id;
    }

    return el.id.replace(/_bttn$/, "");
  }

  function setBusy(downloadId) {
    var button = visibleButton(downloadId);

    if (!button) {
      return;
    }

    if (button.classList.contains("download-busy")) {
      return;
    }

    button.classList.add("download-busy");
    button.setAttribute("aria-busy", "true");

    button._downloadFeedback = document.createElement("span");
    button._downloadFeedback.className = "download-feedback";
    button._downloadFeedback.innerHTML =
      '<span class="download-spinner"></span><span>Preparing...</span>';
    button.appendChild(button._downloadFeedback);

    clearTimeout(button._downloadTimer);
    button._downloadTimer = setTimeout(function() {
      clearBusy(downloadId);
    }, fallbackMs);
  }

  function clearBusy(id) {
    var button = visibleButton(id);

    if (!button || !button.classList.contains("download-busy")) {
      return;
    }

    clearTimeout(button._downloadTimer);
    button.classList.remove("download-busy");
    button.removeAttribute("aria-busy");

    if (button._downloadFeedback) {
      button._downloadFeedback.remove();
      button._downloadFeedback = null;
    }
  }

  document.addEventListener("click", function(event) {
    var button = event.target.closest(
      "button[id$='_bttn'], .shiny-download-link"
    );

    if (!button) {
      return;
    }

    setBusy(downloadId(button));
  });

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("download-ready", clearBusy);
  }
})();
