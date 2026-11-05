field_resightings_save_test_env <- function() {
  env <- new.env(parent = globalenv())
  source_app_file(app_file("main", "R", "field_resightings.R"), env)
  env
}


test_that("resighting inserts require and save a fresh GPS fix", {
  env <- field_resightings_save_test_env()
  writes <- list()
  writer <- function(sql, params) {
    writes[[length(writes) + 1L]] <<- list(sql = sql, params = params)
    TRUE
  }
  now <- as.POSIXct("2026-11-05 12:00:00", tz = "UTC")
  location <- list(latitude = 0.001, longitude = 0.002, accuracy = 7.5,
    timestamp = as.numeric(now) * 1000)
  browser_id <- "00000000-0000-4000-8000-000000000001"
  expect_true(env$field_resightings_save_resighting("rr-or", c("FA", "PR", "FA"),
    location, db_write = writer, now = now, browser_id = browser_id))
  expect_match(writes[[1L]]$sql, "INSERT INTO RESIGHTINGS_field", fixed = TRUE)
  expect_no_match(writes[[1L]]$sql, "RR|OR|FA|PR|0.001")
  expect_identical(writes[[1L]]$params, list(
    NA_character_, "RR", NA_character_, "OR",
    0.001, 0.002, 7.5, "2026-11-05 12:00:00.000", "FA, PR", browser_id
  ))
  for (bad in list(NULL,
      location[c("latitude", "longitude")],
      location[c("latitude", "timestamp")],
      location[c("longitude", "timestamp")],
      modifyList(location, list(timestamp = as.numeric(now) * 1000 - 31000)),
      modifyList(location, list(timestamp = as.numeric(now) * 1000 + 6000)),
      modifyList(location, list(latitude = 91)),
      modifyList(location, list(longitude = "0.002")))) {
    expect_error(env$field_resightings_save_resighting("RROR", "RS", bad,
      db_write = writer, now = now), "GPS unavailable.", fixed = TRUE)
    expect_length(writes, 1L)
  }
  location$accuracy <- -1
  expect_true(env$field_resightings_save_resighting("RROR", "AT", location,
    db_write = writer, now = now, browser_id = browser_id))
  expect_true(is.na(utils::tail(writes, 1L)[[1L]]$params[[7L]]))
  for (ms in c(1, 123, 500, 999)) {
    location$timestamp <- as.numeric(now) * 1000 + ms
    expect_true(env$field_resightings_save_resighting("RROR", "FA", location,
      db_write = writer, now = now + 1, browser_id = browser_id))
    expect_identical(utils::tail(writes, 1L)[[1L]]$params[[8L]],
      paste0("2026-11-05 12:00:00.", sprintf("%03d", ms)))
  }
  count <- length(writes)
  for (bad_id in list(NULL, "", "not-a-uuid", NA_character_, c(browser_id, browser_id))) {
    expect_error(env$field_resightings_save_resighting("RROR", "FA", location,
      db_write = writer, now = now, browser_id = bad_id), "Browser ID unavailable.", fixed = TRUE)
  }
  for (bad in list(NULL, character(), "INVALID", "FA, PR", NA_character_, "FA'); DROP TABLE x;--")) {
    expect_error(env$field_resightings_save_resighting("RROR", bad, db_write = writer),
      "Choose a behaviour", fixed = TRUE)
  }
  expect_error(env$field_resightings_save_resighting("RROR'", "FA", db_write = writer))
  expect_length(writes, count)
  expect_false(env$field_resightings_save_resighting("RROR", "FA", location,
    db_write = function(...) FALSE, now = now, browser_id = browser_id))
})


test_that("save controls bind to the displayed search and prevent repeated writes", {
  env <- field_resightings_save_test_env()
  writes <- list()
  replies <- list()
  control <- new.env()
  control$write_ok <- TRUE
  env$DBx <- function(sql, params) {
    writes[[length(writes) + 1L]] <<- params
    control$write_ok
  }
  env$field_resightings_fetch <- function(combo, refdate) {
    list(combo = combo, refdate = refdate,
      sources = list(CAPTURES = list(failed = FALSE, more = FALSE,
        rows = data.frame(ring = "MOCK001"))))
  }
  server <- function(input, output, session) {
    session$sendCustomMessage <- function(type, message) {
      replies[[length(replies) + 1L]] <<- list(type = type, message = message)
    }
    refdate <- shiny::reactiveVal(as.Date("2026-11-05"))
    search_result <- env$field_resightings_server(input, output, refdate, session)
  }
  shiny::testServer(server, {
    session$flushReact()
    session$setInputs(field_resightings_request = list(combo = "RROR"))
    token <- search_result()$save_token
    html <- output$field_resightings_results$html
    expect_match(html, "field-resightings-save-form", fixed = TRUE)
    expect_match(html, "Save resighting", fixed = TRUE)
    expect_match(html, "Foraging alone", fixed = TRUE)
    expect_match(html, "field-resightings-behaviour-grid", fixed = TRUE)
    expect_match(html, "<dialog", fixed = TRUE)
    expect_match(html, "field-resightings-behaviour-selected", fixed = TRUE)
    expect_match(html, "Choose behaviour", fixed = TRUE)
    expect_match(html, "Done", fixed = TRUE)
    expect_match(html, "Feeding", fixed = TRUE)
    expect_match(html, "Nest/chicks", fixed = TRUE)
    expect_no_match(html, "<select", fixed = TRUE)
    expect_no_match(html, "Tap all that apply", fixed = TRUE)
    expect_equal(length(regmatches(html, gregexpr('type="checkbox"', html, fixed = TRUE))[[1L]]),
      length(env$field_resightings_behaviours()))
    expect_length(writes, 0L)
    request <- jsonlite::fromJSON(paste0(
      '{"token":"', token, '","combo":"RROR","behaviours":["FA"]}'
    ), simplifyVector = FALSE)
    session$setInputs(field_resightings_save_request = request)
    expect_length(writes, 0L)
    expect_identical(utils::tail(replies, 1L)[[1L]]$message$message, "GPS unavailable.")
    request$location <- list(latitude = 0.001, longitude = 0.002,
      timestamp = as.numeric(Sys.time()) * 1000)
    session$setInputs(field_resightings_save_request = request)
    expect_length(writes, 0L)
    expect_identical(utils::tail(replies, 1L)[[1L]]$message$message, "Browser ID unavailable.")
    request$browser_id <- "00000000-0000-4000-8000-000000000001"
    session$setInputs(field_resightings_save_request = modifyList(request, list(behaviours = "BAD")))
    expect_length(writes, 0L)
    expect_false(utils::tail(replies, 1L)[[1L]]$message$saved)
    session$setInputs(field_resightings_save_request = modifyList(request, list(token = "OLD")))
    session$setInputs(field_resightings_save_request = modifyList(request, list(combo = "BYGB")))
    expect_length(writes, 0L)
    session$setInputs(field_resightings_save_request = request)
    expect_length(writes, 1L)
    expect_identical(writes[[1L]][c(2L, 4L, 9L)], list("RR", "OR", "FA"))
    expect_true(utils::tail(replies, 1L)[[1L]]$message$saved)
    session$setInputs(field_resightings_save_request = modifyList(request, list(behaviours = "PR")))
    expect_length(writes, 1L)
    session$setInputs(field_resightings_request = list(combo = "BYGB"))
    new_request <- list(token = search_result()$save_token, combo = "BYGB", behaviours = "RS",
      location = request$location, browser_id = request$browser_id)
    session$setInputs(field_resightings_save_request = request)
    expect_length(writes, 1L)
    control$write_ok <- FALSE
    session$setInputs(field_resightings_save_request = new_request)
    expect_length(writes, 2L)
    expect_false(utils::tail(replies, 1L)[[1L]]$message$saved)
    control$write_ok <- TRUE
    session$setInputs(field_resightings_save_request = new_request)
    expect_length(writes, 3L)
    expect_true(utils::tail(replies, 1L)[[1L]]$message$saved)
    refdate(as.Date("2026-11-04"))
    session$setInputs(field_resightings_save_request = new_request)
    expect_length(writes, 3L)
    expect_false(utils::tail(replies, 1L)[[1L]]$message$saved)
  })
})


test_that("DBx saves field resightings in the disposable MariaDB table", {
  socket <- Sys.getenv("FIELDWORKER_FIELD_RESIGHTINGS_TEST_SOCKET", unset = "")
  skip_if(!nzchar(socket), "Disposable MariaDB fixture not started.")
  skip_if_not_installed("RMariaDB")
  env <- field_resightings_save_test_env()
  source_app_file(app_file("main", "R", "system_utils.R"), env)
  env$db_con <- function() {
    DBI::dbConnect(RMariaDB::MariaDB(), unix.socket = socket, username = "root",
      dbname = "field_resightings_synthetic", default.file = "/dev/null")
  }
  env$dbExecute <- DBI::dbExecute
  env$dbDisconnect <- DBI::dbDisconnect
  env$data.table <- data.table::data.table
  env$isRunning <- function() FALSE
  sql <- readLines(app_file("DATABASE", "main_tables.SQL"))
  start <- which(sql == 'CREATE TABLE `RESIGHTINGS_field` (')
  end <- start + which(grepl("^\\) ENGINE=", sql[(start + 1L):length(sql)]))[[1L]]
  expect_true(env$DBx(paste(sql[start:end], collapse = "\n")))
  now <- as.POSIXct("2026-11-05 12:00:00", tz = "UTC")
  expect_true(env$field_resightings_save_resighting("RROR", c("FA", "PR"),
    list(latitude = 0.001, longitude = 0.002, accuracy = 7.5,
      timestamp = as.numeric(now) * 1000), now = now,
    browser_id = "00000000-0000-4000-8000-000000000001"))
  expect_error(env$field_resightings_save_resighting("BYGB", "RS"), "GPS unavailable.", fixed = TRUE)
  expect_true(env$field_resightings_save_resighting("BYGB", "RS",
    list(latitude = 0, longitude = 0, timestamp = as.numeric(now) * 1000), now = now,
    browser_id = "00000000-0000-4000-8000-000000000001"))
  rows <- env$DBq("SELECT * FROM RESIGHTINGS_field ORDER BY pk", notify = FALSE)
  expect_equal(nrow(rows), 2L)
  expect_identical(rows$LL, c("RR", "BY"))
  expect_identical(rows$LR, c("OR", "GB"))
  expect_false("observer" %in% names(rows))
  expect_true(all(c("browser_id", "gps_timestamp") %in% names(rows)))
  expect_identical(rows$browser_id, rep("00000000-0000-4000-8000-000000000001", 2L))
  expect_identical(rows$behav, c("FA, PR", "RS"))
  expect_equal(rows$latitude[[1L]], 0.001)
  expect_equal(rows$longitude[[1L]], 0.002)
  expect_equal(rows$location_error[[1L]], 7.5)
  expect_equal(rows$latitude[[2L]], 0)
  expect_true(all(!is.na(rows$gps_timestamp)))
  expect_identical(format(rows$gps_timestamp[[1L]], tz = "UTC", usetz = FALSE),
    "2026-11-05 12:00:00")
  expect_true(is.na(rows$location_error[[2L]]))
  expect_identical(rows$pk, 1:2)
})
