load_journal_app <- function() {
  env <- new.env(parent = globalenv())
  directory <- app_file("DataEntry", "field_joirnal")
  source_app_file(file.path(directory, "global.R"), env)
  list(env = env,
       ui = source_app_file(file.path(directory, "ui.R"), env),
       server = source_app_file(file.path(directory, "server.R"), env))
}

local_journal_database <- function(.local_envir = parent.frame()) {
  state <- new.env(parent = emptyenv())
  state$calls <- list()
  state$closed <- state$committed <- state$rolled_back <- 0L
  state$affected <- 1L
  state$fail <- state$warn <- state$commit_error <- FALSE
  testthat::local_mocked_bindings(
    db_con = function(group) {
      expect_identical(group, "nz_fieldworker")
      structure(list(), class = "journal_mock_connection")
    }, .package = "DataEntry", .env = .local_envir
  )
  testthat::local_mocked_bindings(
    dbBegin = function(conn, ...) TRUE,
    dbExecute = function(conn, statement, params, ...) {
      state$calls[[length(state$calls) + 1L]] <- list(statement = statement, params = params)
      if (state$fail) stop("Synthetic database write failure")
      if (state$warn) warning("Synthetic truncation warning")
      state$affected
    },
    dbGetQuery = function(conn, statement, ...) {
      expect_identical(statement, "SELECT LAST_INSERT_ID() AS pk")
      data.frame(pk = 7L)
    },
    dbCommit = function(conn, ...) {
      if (state$commit_error) stop("Synthetic connection loss during commit")
      state$committed <- state$committed + 1L
      TRUE
    },
    dbRollback = function(conn, ...) { state$rolled_back <- state$rolled_back + 1L; TRUE },
    dbDisconnect = function(conn, ...) { state$closed <- state$closed + 1L; TRUE },
    .package = "DBI", .env = .local_envir
  )
  state
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
  db <- local_journal_database()
  photo <- as.raw(c(0, 255, 13, 10))
  receipt <- app$env$journal_save(as.Date("2026-11-21"), "AB", "Invented 'observation'", photo)
  app$env$journal_save(as.Date("2026-11-21"), "", "")
  expect_identical(receipt$pk, "7")
  expect_match(db$calls[[1]]$statement, "VALUES (?, ?, ?, ?)", fixed = TRUE)
  expect_identical(db$calls[[1]]$params, list("2026-11-21", "AB", "Invented 'observation'", list(photo)))
  expect_identical(db$calls[[2]]$params[[4]], list(NULL))
  expect_identical(db$closed, 2L)
  expect_identical(db$committed, 2L)
  expect_identical(db$rolled_back, 0L)
})

test_that("journal saves once per click, preserves failed forms, and resets successful entries", {
  app <- load_journal_app()
  attempts <- 0L
  saved <- NULL
  app$env$journal_save <- function(date, observer, entry, photo) {
    attempts <<- attempts + 1L
    if (attempts == 1L) stop("Invented connection failure")
    saved <<- list(date, observer, entry, photo)
    list(pk = "7")
  }
  photo <- jpeg::writeJPEG(matrix(0.5, 4, 6), raw())
  upload <- list(state = "ready", data = paste0("data:image/jpeg;base64,", jsonlite::base64_enc(photo)))
  shiny::testServer(app$server, {
    session$flushReact()
    session$setInputs(date = as.Date("2026-11-21"), observer = "AB", entry = "Invented note",
                      photo = upload)
    session$setInputs(save = 1L)
    expect_match(output$save_status$html, "Entry was not saved", fixed = TRUE)
    expect_identical(input$entry, "Invented note")
    session$setInputs(save = 2L)
    expect_match(output$save_status$html, "reference #7", fixed = TRUE)
    expect_match(output$save_status$html, "alert-success", fixed = TRUE)
    expect_identical(saved[[4]], photo)
    expect_identical(attempts, 2L)
    session$setInputs(photo = list(state = "ready", data = paste0("data:image/jpeg;base64,", strrep("A", 700000))))
    session$setInputs(save = 3L)
    expect_match(output$save_status$html, "too large", fixed = TRUE)
    expect_identical(attempts, 2L)
  })
})

test_that("journal first click without a photo saves and repeated failures remain visible", {
  app <- load_journal_app()
  db <- local_journal_database()
  shiny::testServer(app$server, {
    session$flushReact()
    expect_length(db$calls, 0L)
    session$setInputs(date = as.Date("2026-11-21"), observer = "AB", entry = "Invented note")
    session$setInputs(save = 1L)
    expect_length(db$calls, 1L)
    expect_match(output$save_status$html, "reference #7", fixed = TRUE)
    db$fail <- TRUE
    session$setInputs(save = 2L)
    first <- output$save_status$html
    session$setInputs(save = 3L)
    second <- output$save_status$html
    expect_false(identical(first, second))
    expect_match(second, "alert-danger", fixed = TRUE)
    expect_match(second, "Your text and photo have been kept", fixed = TRUE)
    expect_identical(db$rolled_back, 2L)
    expect_identical(db$committed, 1L)
  })
})

test_that("journal never confirms zero-row, warned, or uncertain writes", {
  app <- load_journal_app()
  db <- local_journal_database()
  save <- function() app$env$journal_save(as.Date("2026-11-21"), "AB", "Invented note")
  db$affected <- 0L
  expect_error(save(), "exactly one")
  db$affected <- 1L
  db$warn <- TRUE
  expect_error(save(), "could not store it completely")
  db$warn <- FALSE
  db$commit_error <- TRUE
  result <- tryCatch(save(), error = identity)
  expect_identical(result$state, "uncertain")
  expect_match(conditionMessage(result), "Check the journal before trying again", fixed = TRUE)
  expect_identical(db$committed, 0L)
  expect_identical(db$rolled_back, 3L)
  expect_identical(db$closed, 3L)
})

test_that("journal table browser escapes observations and links photos without fetching binary data", {
  env <- new.env(parent = globalenv())
  sys.source(app_file("main", "R", "system_utils.R"), env)
  env$data.table <- data.table::data.table
  env$set <- data.table::set
  env$DBq <- function(sql) {
    expect_match(sql, "OCTET_LENGTH(`photo`)", fixed = TRUE)
    expect_match(sql, "ELSE `pk` END AS `photo`", fixed = TRUE)
    data.frame(date = as.Date(c("2026-11-21", "2026-11-20")), observer = c("AB", "CD"),
               entry = c("<script>invented</script>", "Invented note"), photo = c(7L, NA_integer_))
  }
  rows <- env$showTable("field_joirnal", photo_url = "session/synthetic/dataobj/photo?w=0")
  expect_identical(rows$date, c("2026-11-21", "2026-11-20"))
  expect_identical(rows$entry[[1]], "&lt;script&gt;invented&lt;/script&gt;")
  expect_match(rows$photo[[1]], "<img", fixed = TRUE)
  expect_match(rows$photo[[1]], 'loading="lazy"', fixed = TRUE)
  expect_match(rows$photo[[1]], "pk=7", fixed = TRUE)
  expect_identical(rows$photo[[2]], "")
})

test_that("journal image endpoint returns binary photos only for valid references", {
  env <- new.env(parent = globalenv())
  sys.source(app_file("main", "R", "system_utils.R"), env)
  photo <- jpeg::writeJPEG(matrix(0.5, 4, 6), raw())
  calls <- 0L
  env$DBq <- function(sql, params, notify) {
    calls <<- calls + 1L
    expect_identical(sql, "SELECT `photo` FROM `field_joirnal` WHERE `pk` = ? LIMIT 1")
    expect_identical(params, list("7"))
    expect_false(notify)
    rows <- data.frame(id = 7L)
    rows$photo <- list(photo)
    rows
  }
  request <- list(QUERY_STRING = "w=0&pk=7")
  response <- env$field_journal_photo_response(request)
  expect_identical(response$status, 200L)
  expect_identical(response$content_type, "image/jpeg")
  expect_identical(response$content, photo)
  expect_identical(env$field_journal_photo_response(list(QUERY_STRING = "pk=7%20OR%201=1"))$status, 400L)
  expect_identical(calls, 1L)
  photo <- NULL
  expect_identical(env$field_journal_photo_response(request)$status, 404L)
  photo <- charToRaw("<html>invented invalid image</html>")
  expect_identical(env$field_journal_photo_response(request)$status, 415L)
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
