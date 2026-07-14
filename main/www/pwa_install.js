(function() {
  "use strict";

  var installPrompt = null;
  var standaloneQuery = window.matchMedia("(display-mode: standalone)");

  function installButton() {
    return document.getElementById("install_mobile");
  }

  function closestInstallButton(target) {
    while (target && target !== document) {
      if (target.id === "install_mobile") {
        return target;
      }

      target = target.parentElement;
    }

    return null;
  }

  function isStandalone() {
    return standaloneQuery.matches || window.navigator.standalone === true;
  }

  function isIosLike() {
    return /iPad|iPhone|iPod/.test(window.navigator.userAgent) ||
      (window.navigator.platform === "MacIntel" && window.navigator.maxTouchPoints > 1);
  }

  function fallbackInstallMessage() {
    var message = "Use your browser menu and choose 'Install app' or 'Add to Home screen'.";

    if (isIosLike()) {
      message = "Use the browser Share menu and choose 'Add to Home Screen'.";
    }

    window.alert(message);
  }

  function updateInstallButtonState() {
    var button = installButton();

    if (!button) {
      return;
    }

    if (isStandalone()) {
      button.hidden = true;
      button.disabled = true;
      button.setAttribute("aria-hidden", "true");
      return;
    }

    button.hidden = false;
    button.disabled = false;
    button.removeAttribute("aria-hidden");
    button.dataset.installReady = installPrompt ? "true" : "false";
    button.title = installPrompt ?
      "Install Fieldworker on this device" :
      "Show app installation instructions";
  }

  function skipWaitingWhenReady(worker) {
    if (!worker) {
      return;
    }

    if (worker.state === "installed") {
      worker.postMessage({ type: "SKIP_WAITING" });
      return;
    }

    worker.addEventListener("statechange", function() {
      if (worker.state === "installed") {
        worker.postMessage({ type: "SKIP_WAITING" });
      }
    });
  }

  function registerServiceWorker() {
    if (!("serviceWorker" in navigator)) {
      updateInstallButtonState();
      return;
    }

    navigator.serviceWorker.register("service-worker.js", {
      scope: "./",
      updateViaCache: "none"
    }).then(function(registration) {
      if (registration.waiting) {
        registration.waiting.postMessage({ type: "SKIP_WAITING" });
      }

      registration.addEventListener("updatefound", function() {
        skipWaitingWhenReady(registration.installing);
      });

      if (registration.update) {
        return registration.update().catch(function(error) {
          console.warn("[pwa] Service worker update check failed:", error);
        });
      }

      return null;
    }).catch(function(error) {
      console.warn("[pwa] Service worker registration failed:", error);
    }).finally(updateInstallButtonState);
  }

  window.addEventListener("load", registerServiceWorker);

  window.addEventListener("beforeinstallprompt", function(event) {
    event.preventDefault();
    installPrompt = event;
    updateInstallButtonState();
  });

  window.addEventListener("appinstalled", function() {
    installPrompt = null;
    updateInstallButtonState();
  });

  if (standaloneQuery.addEventListener) {
    standaloneQuery.addEventListener("change", updateInstallButtonState);
  } else if (standaloneQuery.addListener) {
    standaloneQuery.addListener(updateInstallButtonState);
  }

  document.addEventListener("DOMContentLoaded", updateInstallButtonState);

  document.addEventListener("click", function(event) {
    var button = closestInstallButton(event.target);

    if (!button) {
      return;
    }

    event.preventDefault();

    if (isStandalone()) {
      updateInstallButtonState();
      return;
    }

    if (!installPrompt) {
      fallbackInstallMessage();
      return;
    }

    button.disabled = true;

    var promptPromise;

    try {
      promptPromise = installPrompt.prompt();
    } catch (error) {
      console.warn("[pwa] Install prompt failed:", error);
      installPrompt = null;
      button.disabled = false;
      updateInstallButtonState();
      return;
    }

    Promise.resolve(promptPromise)
      .then(function() {
        return installPrompt.userChoice;
      })
      .catch(function(error) {
        console.warn("[pwa] Install prompt failed:", error);
      })
      .finally(function() {
        installPrompt = null;
        button.disabled = false;
        updateInstallButtonState();
      });
  });
})();
