load_journal_app <- function() {
  env <- new.env(parent = globalenv())
  directory <- app_file("DataEntry", "field_joirnal")
  source_app_file(file.path(directory, "global.R"), env)
  list(env = env,
       ui = source_app_file(file.path(directory, "ui.R"), env),
       server = source_app_file(file.path(directory, "server.R"), env))
}

test_that("journal form is a single entry without the validation grid", {
  app <- load_journal_app()
  html <- htmltools::renderTags(app$ui)$html
  expect_match(html, "Field journal", fixed = TRUE)
  for (id in c("date", "observer", "entry", "save")) {
    expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
  }
  expect_no_match(html, "ignore_checks|handsontable")
  globals <- paste(readLines(app_file("main", "global.R")), collapse = "\n")
  expr <- parse(text = globals)
  env <- new.env()
  for (x in expr) {
    if (is.call(x) && identical(x[[1]], as.name("<-")) &&
        as.character(x[[2]]) %in% c("dbtabs_entry", "dbtabs_show_tables")) eval(x, env)
  }
  expect_contains(env$dbtabs_entry, "field_joirnal")
  expect_contains(env$dbtabs_show_tables, "field_joirnal")
})

test_that("journal writer binds binary photos and SQL NULL with a dedicated connection", {
  app <- load_journal_app()
  calls <- list()
  disconnected <- 0L
  testthat::local_mocked_bindings(
    db_con = function(group) {
      expect_identical(group, "nz_fieldworker")
      structure(list(), class = "journal_mock_connection")
    }, .package = "DataEntry"
  )
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, params, ...) {
      expect_match(statement, "VALUES (?, ?, ?, ?)", fixed = TRUE)
      expect_match(statement, "INSERT INTO `field_joirnal`", fixed = TRUE)
      calls[[length(calls) + 1L]] <<- params
      1L
    },
    dbDisconnect = function(conn, ...) { disconnected <<- disconnected + 1L; TRUE },
    .package = "DBI"
  )
  photo <- as.raw(c(0, 255, 13, 10))
  app$env$journal_save(as.Date("2026-11-21"), "AB", "Invented 'observation'", photo)
  app$env$journal_save(as.Date("2026-11-21"), "", "")
  expect_identical(calls[[1]], list("2026-11-21", "AB", "Invented 'observation'", list(photo)))
  expect_identical(calls[[2]][[4]], list(NULL))
  expect_identical(disconnected, 2L)
})

test_that("journal saves once per click, preserves failed forms, and resets successful entries", {
  app <- load_journal_app()
  attempts <- 0L
  saved <- NULL
  app$env$journal_save <- function(date, observer, entry, photo) {
    attempts <<- attempts + 1L
    if (attempts == 1L) stop("Invented connection failure")
    saved <<- list(date, observer, entry, photo)
  }
  photo <- jpeg::writeJPEG(matrix(0.5, 4, 6), raw())
  upload <- list(state = "ready", data = paste0("data:image/jpeg;base64,", jsonlite::base64_enc(photo)))
  shiny::testServer(app$server, {
    session$flushReact()
    session$setInputs(date = as.Date("2026-11-21"), observer = "AB", entry = "Invented note",
                      photo = upload)
    session$setInputs(save = 1L)
    expect_match(output$save_status, "Could not save", fixed = TRUE)
    expect_identical(input$entry, "Invented note")
    session$setInputs(save = 2L)
    expect_match(output$save_status, "Entry saved", fixed = TRUE)
    expect_identical(saved[[4]], photo)
    expect_identical(attempts, 2L)
    session$setInputs(photo = list(state = "ready", data = paste0("data:image/jpeg;base64,", strrep("A", 700000))))
    session$setInputs(save = 3L)
    expect_match(output$save_status, "too large", fixed = TRUE)
    expect_identical(attempts, 2L)
  })
})

test_that("journal table browser escapes observations and shows photo sizes without binary data", {
  env <- new.env(parent = globalenv())
  sys.source(app_file("main", "R", "system_utils.R"), env)
  env$data.table <- data.table::data.table
  env$set <- data.table::set
  env$DBq <- function(sql) {
    expect_match(sql, "OCTET_LENGTH(`photo`)", fixed = TRUE)
    data.frame(date = as.Date("2026-11-21"), observer = "AB",
               entry = "<script>invented</script>", photo = "Photo attached (4 bytes)")
  }
  rows <- env$showTable("field_joirnal")
  expect_identical(rows$date, "2026-11-21")
  expect_identical(rows$entry, "&lt;script&gt;invented&lt;/script&gt;")
  expect_identical(rows$photo, "Photo attached (4 bytes)")
})

test_that("journal upload checks reject unfinished, oversized, and invalid images", {
  app <- load_journal_app()
  expect_null(app$env$journal_photo(NULL))
  expect_null(app$env$journal_photo(list(state = "none")))
  for (state in c("processing", "error")) {
    expect_error(app$env$journal_photo(list(state = state)), "Wait for the photo preview")
  }
  upload <- function(bytes) {
    list(state = "ready", data = paste0("data:image/jpeg;base64,", jsonlite::base64_enc(bytes)))
  }
  expect_error(app$env$journal_photo(list(state = "ready", data = "data:image/png;base64,AA==")), "JPEG")
  expect_error(app$env$journal_photo(upload(charToRaw("invented invalid image"))), "JPEG")
  # A valid JPEG header with an excessive width must fail before image decoding.
  huge <- jpeg::writeJPEG(matrix(0.5, 2, 1601), raw())
  expect_error(app$env$journal_photo(upload(huge)), "1,600 pixels")
  photo <- jpeg::writeJPEG(matrix(0.5, 10, 16), raw())
  expect_identical(app$env$journal_photo(upload(photo)), photo)
  expect_error(app$env$journal_photo(upload(head(photo, -20))), "could not be read")
})
