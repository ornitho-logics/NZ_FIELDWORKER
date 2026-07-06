(function() {
  var installPrompt = null;

  function installButton() {
    return document.getElementById("install_mobile");
  }

  function fallbackInstallMessage() {
    window.alert(
      "Use your browser menu and choose 'Add to Home screen' or 'Install app'."
    );
  }

  if ("serviceWorker" in navigator) {
    window.addEventListener("load", function() {
      navigator.serviceWorker.register("service-worker.js");
    });
  }

  window.addEventListener("beforeinstallprompt", function(event) {
    event.preventDefault();
    installPrompt = event;
  });

  window.addEventListener("appinstalled", function() {
    installPrompt = null;
  });

  document.addEventListener("click", function(event) {
    if (!event.target.closest("#install_mobile")) {
      return;
    }

    if (!installPrompt) {
      fallbackInstallMessage();
      return;
    }

    installPrompt.prompt();
    installPrompt.userChoice.finally(function() {
      installPrompt = null;
    });
  });
})();
