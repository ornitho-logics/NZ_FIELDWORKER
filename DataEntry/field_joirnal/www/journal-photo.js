/* Only the resized JPEG is sent to Shiny. The selected original stays local. */
"use strict";

window.jQuery(function () {
  const picker = document.querySelector(".journal-photo-picker");
  const preview = document.getElementById("photo-preview");
  const message = document.getElementById("photo-status");
  const remove = document.getElementById("photo-remove");
  const save = document.getElementById("save");
  let generation = 0;
  let previewUrl = null;
  const limit = 500000;

  function publish(value) {
    window.Shiny.setInputValue("photo", value, {priority: "event"});
  }

  function clearPreview() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    previewUrl = null;
    preview.removeAttribute("src");
    preview.hidden = true;
  }

  function reset() {
    generation += 1;
    picker.value = "";
    clearPreview();
    message.textContent = "";
    remove.hidden = true;
    save.disabled = false;
    publish({state: "none"});
  }

  function jpeg(canvas, quality) {
    return new Promise((resolve, reject) => {
      canvas.toBlob(blob => {
        if (blob && blob.type === "image/jpeg") resolve(blob);
        else reject(new Error("JPEG conversion is unavailable in this browser."));
      }, "image/jpeg", quality);
    });
  }

  function dataUrl(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(new Error("The prepared photo could not be read."));
      reader.readAsDataURL(blob);
    });
  }

  // The browser applies image orientation when decoding the selected photo.
  function decode(file) {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const image = new Image();
      image.onload = () => { URL.revokeObjectURL(url); resolve(image); };
      image.onerror = () => {
        URL.revokeObjectURL(url);
        reject(new Error("This photo format cannot be opened here. Try a JPEG or PNG."));
      };
      image.src = url;
    });
  }

  picker.addEventListener("change", async function () {
    const file = picker.files[0];
    if (!file) { reset(); return; }
    const current = ++generation;
    clearPreview();
    remove.hidden = false;
    save.disabled = true;
    message.textContent = "Preparing photo…";
    publish({state: "processing"});
    try {
      // Bound local decoding costs on phones; this is not an upload limit.
      if (file.size > 50 * 1024 * 1024) {
        throw new Error("Choose a photo smaller than 50 MB for this device to resize.");
      }
      const image = await decode(file);
      if (current !== generation) return;
      const scale = Math.min(1, 1600 / Math.max(image.naturalWidth, image.naturalHeight));
      const canvas = document.createElement("canvas");
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
      const context = canvas.getContext("2d");
      if (!context) throw new Error("Photo resizing is unavailable in this browser.");
      // JPEG has no transparency; use white for transparent source pixels.
      context.fillStyle = "white";
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      let blob;
      for (const quality of [0.8, 0.7, 0.6, 0.5]) {
        blob = await jpeg(canvas, quality);
        if (current !== generation) return;
        if (blob.size <= limit) break;
      }
      // Detailed images may need fewer pixels as well as lower JPEG quality.
      while (blob.size > limit && Math.max(canvas.width, canvas.height) > 320) {
        const smaller = document.createElement("canvas");
        smaller.width = Math.max(1, Math.round(canvas.width * 0.8));
        smaller.height = Math.max(1, Math.round(canvas.height * 0.8));
        smaller.getContext("2d").drawImage(canvas, 0, 0, smaller.width, smaller.height);
        canvas.width = smaller.width;
        canvas.height = smaller.height;
        context.drawImage(smaller, 0, 0);
        blob = await jpeg(canvas, 0.7);
        if (current !== generation) return;
      }
      if (blob.size > limit) throw new Error("The photo could not be reduced enough. Choose another photo.");
      const encoded = await dataUrl(blob);
      if (current !== generation) return;
      previewUrl = URL.createObjectURL(blob);
      preview.src = previewUrl;
      preview.hidden = false;
      message.textContent = `${canvas.width} × ${canvas.height} pixels · ${Math.ceil(blob.size / 1000)} KB · ready to save`;
      publish({state: "ready", data: encoded});
      save.disabled = false;
    } catch (error) {
      if (current !== generation) return;
      message.textContent = error.message || "Could not prepare this photo. Choose another photo.";
      publish({state: "error"});
      // Removing the failed photo also lets the user save the written entry.
      save.disabled = true;
    }
  });

  remove.addEventListener("click", reset);
  window.Shiny.addCustomMessageHandler("journal-photo-reset", function (message) {
    reset();
  });
});
