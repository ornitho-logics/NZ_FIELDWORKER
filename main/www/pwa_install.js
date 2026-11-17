(function() {
  "use strict";

  var installPrompt = null;
  var installedThisVisit = false;
  var installBusy = false;
  var standaloneQuery = window.matchMedia("(display-mode: standalone)");
  var registration = null;
  var waitingWorker = null;
  var watchedWorkers = new WeakSet();
  var latestBuild = null;
  var dismissedBuild = null;
  var checkPromise = null;
  var lastCheck = 0;
  var reloadRequested = false;
  var reloadTimer = null;
  var buildMeta = document.querySelector('meta[name="fieldworker-build"]');
  var currentBuild = buildMeta ? buildMeta.content : "unknown";
  var manifest = document.querySelector('link[rel="manifest"]');
  var appRoot = new URL("./", manifest ? manifest.href : window.location.href);
  var tabKey = "fieldworker-tab:" + appRoot.pathname;

  function element(id) { return document.getElementById(id); }
  function text(id, value) {
    var node = element(id);
    if (node) node.textContent = value;
  }
  function isStandalone() {
    return standaloneQuery.matches || window.navigator.standalone === true;
  }
  function isIosLike() {
    return /iPad|iPhone|iPod/.test(window.navigator.userAgent) ||
      (window.navigator.platform === "MacIntel" && window.navigator.maxTouchPoints > 1);
  }
  function validBuild(id) { return typeof id === "string" && /^[a-f0-9]{64}$/.test(id); }
  function workerBuild(worker) {
    return worker ? new URL(worker.scriptURL).searchParams.get("build") : null;
  }

  function updateInstallButtonState() {
    var button = element("install_mobile");
    var help = element("install_help");
    if (!button || !help) return;
    var installed = isStandalone() || installedThisVisit;
    button.hidden = installed || !installPrompt;
    button.disabled = installed || installBusy;
    text("install_mobile_label", installBusy ? "Opening installation…" : "Install Fieldworker");
    help.hidden = false;
    help.textContent = installed ? "Fieldworker is ready on your home screen." :
      (isIosLike() ? "In Safari, tap Share, then Add to Home Screen." :
        "In Chrome, open ⋮ and choose Install app or Add to home screen. If already installed, open Fieldworker from your launcher.");
    if (installPrompt && !installed) {
      help.textContent = "Install once, then open Fieldworker from your home screen.";
    }
  }

  function showUpdate() {
    var notice = element("pwa_update_notice");
    if (!notice) return;
    var offeredBuild = latestBuild || workerBuild(waitingWorker) || "worker-update";
    if (dismissedBuild === offeredBuild && !reloadRequested) return;
    notice.hidden = false;
    element("pwa_update").disabled = reloadRequested || navigator.onLine === false ||
      !!(registration && registration.installing && !waitingWorker);
    element("pwa_update_later").disabled = reloadRequested;
    text("pwa_update_detail", reloadRequested ? "Opening the new version…" :
      (navigator.onLine === false ? "Reconnect before updating. Your current page will stay open." :
        "Save your work, then reload when you are ready."));
  }

  function watchWorker(worker) {
    if (!worker || watchedWorkers.has(worker)) return;
    watchedWorkers.add(worker);
    function changed() {
      if (worker.state === "installed" && navigator.serviceWorker.controller) {
        waitingWorker = worker;
        showUpdate();
      } else if (worker.state === "redundant") {
        if (waitingWorker === worker) waitingWorker = null;
        text("pwa_update_status", "The update could not be prepared. Try checking again.");
        if (element("pwa_update")) element("pwa_update").disabled = false;
      }
    }
    worker.addEventListener("statechange", changed);
    changed();
  }

  function updateFound() { watchWorker(registration.installing); }

  async function checkForUpdates(manual) {
    if (manual) dismissedBuild = null;
    if (checkPromise) return checkPromise;
    lastCheck = Date.now();
    var button = element("pwa_check_updates");
    if (button) button.disabled = true;
    text("pwa_update_status", "Checking…");
    checkPromise = (async function() {
      var metadataAvailable = false;
      var abort = new AbortController();
      var timeout = window.setTimeout(function() { abort.abort(); }, 10000);
      try {
        var response = await fetch(new URL("build.json", appRoot), {
          cache: "no-store", signal: abort.signal
        });
        if (!response.ok) throw new Error("Build information unavailable");
        var build = await response.json();
        if (!validBuild(build.id)) throw new Error("Invalid build information");
        latestBuild = build.id;
        metadataAvailable = true;
      } catch (error) {
        console.warn("[pwa] Build check failed:", error);
      } finally {
        window.clearTimeout(timeout);
      }

      if ("serviceWorker" in navigator && window.isSecureContext !== false) {
        var script = new URL("service-worker.js", appRoot);
        if (latestBuild) script.searchParams.set("build", latestBuild);
        try {
          registration = await navigator.serviceWorker.register(script.href, {
            scope: appRoot.href, updateViaCache: "none"
          });
          registration.addEventListener("updatefound", updateFound);
          watchWorker(registration.waiting);
          watchWorker(registration.installing);
          await registration.update();
        } catch (error) {
          console.warn("[pwa] Service worker check failed:", error);
          text("pwa_update_status", "Could not prepare the update. Try again when connected.");
          return;
        }
      }
      if (metadataAvailable && latestBuild !== currentBuild) {
        showUpdate();
        text("pwa_update_status", "A new version is available.");
      } else if (waitingWorker) {
        showUpdate();
        text("pwa_update_status", "An app update is ready.");
      } else {
        text("pwa_update_status", metadataAvailable ? "You are up to date." :
          "Could not check for updates. Try again when connected.");
      }
    })().finally(function() {
      checkPromise = null;
      if (button) button.disabled = false;
    });
    return checkPromise;
  }

  async function install() {
    if (!installPrompt || installBusy) return;
    // appinstalled may clear the shared reference while userChoice is pending.
    var prompt = installPrompt;
    installPrompt = null;
    installBusy = true;
    try {
      await prompt.prompt();
      await prompt.userChoice;
    } catch (error) {
      console.warn("[pwa] Install prompt failed:", error);
    } finally {
      installBusy = false;
      updateInstallButtonState();
    }
  }

  function applyUpdate() {
    if (reloadRequested) return;
    if (navigator.onLine === false) { showUpdate(); return; }
    reloadRequested = true;
    showUpdate();
    if (!waitingWorker || waitingWorker.state !== "installed") {
      window.location.reload();
      return;
    }
    // The old client sent SKIP_WAITING automatically. Only this explicit,
    // versioned request may activate the new worker during the migration.
    try {
      waitingWorker.postMessage({
        type: "FIELDWORKER_APPLY_UPDATE", build: workerBuild(waitingWorker)
      });
    } catch (error) {
      reloadRequested = false;
      waitingWorker = null;
      showUpdate();
      text("pwa_update_detail", "The update changed. Check for updates and try again.");
      return;
    }
    reloadTimer = window.setTimeout(function() {
      reloadRequested = false;
      showUpdate();
      text("pwa_update_detail", "The update did not finish. Check your connection and try again.");
    }, 15000);
  }

  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.addEventListener("controllerchange", function() {
      waitingWorker = null;
      if (reloadRequested) {
        window.clearTimeout(reloadTimer);
        window.location.reload();
      } else if (validBuild(workerBuild(navigator.serviceWorker.controller)) &&
                 workerBuild(navigator.serviceWorker.controller) !== currentBuild) {
        latestBuild = workerBuild(navigator.serviceWorker.controller);
        showUpdate();
      }
    });
  }
  window.addEventListener("beforeinstallprompt", function(event) {
    event.preventDefault();
    installPrompt = event;
    installedThisVisit = false;
    updateInstallButtonState();
  });
  window.addEventListener("appinstalled", function() {
    installedThisVisit = true;
    installPrompt = null;
    updateInstallButtonState();
  });
  if (standaloneQuery.addEventListener) {
    standaloneQuery.addEventListener("change", updateInstallButtonState);
  } else if (standaloneQuery.addListener) {
    standaloneQuery.addListener(updateInstallButtonState);
  }
  function initialize() {
    updateInstallButtonState();
    if (!window.jQuery) return;
    window.jQuery(document).on("shiny:inputchanged", function(event) {
      if (event.name !== "main") return;
      try { window.sessionStorage.setItem(tabKey, event.value); } catch (_) {}
    });
    window.jQuery(document).on("shiny:sessioninitialized", function() {
      var saved;
      try { saved = window.sessionStorage.getItem(tabKey); } catch (_) {}
      var tab = Array.from(document.querySelectorAll("#main [data-value]"))
        .find(function(node) { return node.dataset.value === saved; });
      if (tab) tab.click();
    });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize);
  } else {
    initialize();
  }
  if (document.readyState === "complete") checkForUpdates(false);
  else window.addEventListener("load", function() { checkForUpdates(false); });
  document.addEventListener("visibilitychange", function() {
    if (!document.hidden && Date.now() - lastCheck > 60000) checkForUpdates(false);
  });
  window.addEventListener("online", function() { checkForUpdates(false); });
  window.addEventListener("offline", function() {
    var notice = element("pwa_update_notice");
    if (notice && !notice.hidden) showUpdate();
  });
  document.addEventListener("click", function(event) {
    var target = event.target;
    while (target && target !== document) {
      if (["install_mobile", "pwa_check_updates", "pwa_update", "pwa_update_later"].includes(target.id)) {
        event.preventDefault();
        if (target.disabled) return;
        if (target.id === "install_mobile") install();
        if (target.id === "pwa_check_updates") checkForUpdates(true);
        if (target.id === "pwa_update") applyUpdate();
        if (target.id === "pwa_update_later") {
          dismissedBuild = latestBuild || workerBuild(waitingWorker) || "worker-update";
          element("pwa_update_notice").hidden = true;
        }
        return;
      }
      target = target.parentElement;
    }
  });
})();
