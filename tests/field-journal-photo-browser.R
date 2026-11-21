# Standalone browser integration test. Starts a loopback-only Shiny app with a
# synthetic save function; no database connections or real photos are used.
# Run from the repository root: Rscript --vanilla tests/field-journal-photo-browser.R
root <- normalizePath(".")
port <- httpuv::randomPort()
app_process <- callr::r_bg(function(root, port) {
  source_dir <- file.path(root, "DataEntry", "field_joirnal")
  app_dir <- tempfile("journal-browser-")
  dir.create(app_dir)
  on.exit(unlink(app_dir, recursive = TRUE), add = TRUE)
  file.copy(file.path(source_dir, c("global.R", "ui.R", "server.R")), app_dir)
  file.symlink(file.path(source_dir, "www"), file.path(app_dir, "www"))
  # Override the writer in the disposable copy before any session can start.
  cat("\njournal_save <- function(...) invisible(TRUE)\n",
      file = file.path(app_dir, "global.R"), append = TRUE)
  shiny::runApp(app_dir, host = "127.0.0.1", port = port,
               launch.browser = FALSE, quiet = TRUE)
}, args = list(root, port), stdout = "|", stderr = "|")

run_checks <- function() {
  on.exit(app_process$kill(), add = TRUE)
  browser <- chromote::ChromoteSession$new()
  on.exit(browser$close(), add = TRUE)
  browser$Runtime$enable()
  browser$Runtime$exceptionThrown(function(event) {
    exception <- event$exceptionDetails$exception
    message(if (is.null(exception$description)) exception$value else exception$description)
  })
  browser$Network$enable()
  uploads <- character()
  browser$Network$requestWillBeSent(function(event) {
    if (identical(event$request$method, "POST")) {
      uploads <<- c(uploads, event$request$url)
    }
  })
  address <- paste0("http://127.0.0.1:", port)
  ready <- FALSE
  for (attempt in seq_len(100)) {
    if (!app_process$is_alive()) stop(paste(app_process$read_error(), collapse = "\n"))
    ready <- suppressWarnings(tryCatch(local({
      con <- url(address)
      on.exit(close(con), add = TRUE)
      length(readLines(con, n = 1, warn = FALSE)) > 0
    }), error = function(e) FALSE))
    if (ready) break
    Sys.sleep(0.1)
  }
  stopifnot(ready)
  browser$Page$navigate(address)
  evaluate <- function(code) {
    result <- browser$Runtime$evaluate(code, awaitPromise = TRUE, returnByValue = TRUE,
                                      timeout_ = 60)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description, call. = FALSE)
    }
    result$result$value
  }
  evaluate("new Promise((resolve, reject) => {
    const deadline = Date.now() + 15000;
    const wait = () => {
      if (window.Shiny && Shiny.shinyapp && Shiny.shinyapp.$socket &&
          Shiny.shinyapp.$socket.readyState === 1 && document.getElementById('save')) resolve(true);
      else if (Date.now() > deadline) reject(Error('Shiny did not connect'));
      else setTimeout(wait, 50);
    }; wait();
  })")
  result <- evaluate("(async () => {
    const assert = (value, message) => { if (!value) throw Error(message); };
    const picker = document.querySelector('.journal-photo-picker');
    assert(!picker.classList.contains('shiny-bound-input'), 'Original file picker was bound by Shiny');
    window.photoMessages = [];
    window.customMessages = [];
    window.jQuery(document).on('shiny:message.journalTest', event => {
      if (event.message.custom) customMessages.push(event.message.custom);
    });
    const originalSetInput = Shiny.setInputValue.bind(Shiny);
    Shiny.setInputValue = (id, value, opts) => {
      if (id === 'photo') window.photoMessages.push(value);
      return originalSetInput(id, value, opts);
    };
    const wait = async (predicate) => {
      const end = Date.now() + 20000;
      while (!predicate()) {
        if (Date.now() > end) throw Error('Timed out: ' + document.getElementById('photo-status').textContent +
          '; save status: ' + document.getElementById('save_status').textContent +
          '; custom messages: ' + JSON.stringify(customMessages) +
          '; photo states: ' + photoMessages.map(value => value.state).join(','));
        await new Promise(resolve => setTimeout(resolve, 30));
      }
    };
    const canvas = document.createElement('canvas');
    canvas.width = 2400; canvas.height = 1800;
    const ctx = canvas.getContext('2d');
    const pixels = ctx.createImageData(canvas.width, canvas.height);
    let seed = 123;
    for (let i = 0; i < pixels.data.length; i += 4) {
      for (let c = 0; c < 3; c++) {
        seed = (1664525 * seed + 1013904223) >>> 0;
        pixels.data[i+c] = seed >>> 24;
      }
      pixels.data[i+3] = 255;
    }
    ctx.putImageData(pixels, 0, 0);
    const original = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
    assert(original.size > 500000, 'Fixture must exceed upload limit');
    const choose = (blob, name) => {
      const files = new DataTransfer();
      files.items.add(new File([blob], name, {type: blob.type}));
      picker.files = files.files;
      picker.dispatchEvent(new Event('change', {bubbles: true}));
    };
    choose(original, 'synthetic.png');
    assert(document.getElementById('save').disabled, 'Save allowed while processing');
    await wait(() => photoMessages.at(-1)?.state === 'ready');
    const prepared = photoMessages.at(-1).data;
    const bytes = atob(prepared.split(',')[1]).length;
    const preview = document.getElementById('photo-preview');
    await wait(() => preview.complete && preview.naturalWidth > 0);
    assert(prepared.startsWith('data:image/jpeg;base64,'), 'Prepared photo is not JPEG');
    assert(bytes <= 500000, 'Prepared photo exceeds upload cap');
    assert(preview.naturalWidth <= 1600 && preview.naturalHeight <= 1600, 'Dimensions exceed cap');
    assert(Math.abs(preview.naturalWidth / preview.naturalHeight - 4/3) < .01, 'Aspect ratio changed');
    assert(!document.getElementById('save').disabled, 'Save remains disabled');
    assert(picker.files[0].size === original.size, 'Original was changed');
    Shiny.setInputValue('entry', 'Invented browser test note', {priority: 'event'});
    document.getElementById('save').click();
    await wait(() => document.getElementById('save_status').textContent.includes('Entry saved'));
    await wait(() => photoMessages.at(-1)?.state === 'none');
    assert(preview.hidden && picker.files.length === 0, 'Photo was not cleared after save');
    choose(new Blob(['invalid'], {type: 'image/jpeg'}), 'invalid.jpg');
    await wait(() => photoMessages.at(-1)?.state === 'error');
    assert(document.getElementById('save').disabled, 'Invalid photo could be silently omitted');
    document.getElementById('photo-remove').click();
    assert(!document.getElementById('save').disabled && preview.hidden, 'Removing photo did not reset form');
    choose(original, 'superseded.png');
    document.getElementById('photo-remove').click();
    await new Promise(resolve => setTimeout(resolve, 500));
    assert(photoMessages.at(-1).state === 'none' && preview.hidden, 'Removed photo reappeared after async processing');
    return {originalBytes: original.size, uploadedBytes: bytes, passed: true};
  })()")
  print(result)
  stopifnot(length(uploads) == 0L)
}
run_checks()
