quick_search_test_env <- function() {
  env <- new.env(parent = globalenv())
  source_app_file(app_file("main", "R", "quick_search.R"), env)
  env
}


test_that("optional quick-search failures never display SQL notifications", {
  env <- quick_search_test_env()
  source_app_file(app_file("main", "R", "system_utils.R"), env)
  notices <- character()
  env$db_con <- function() stop("synthetic unavailable source")
  env$isRunning <- function() TRUE
  env$showNotification <- function(message, ...) notices <<- c(notices, message)
  env$str_trunc <- function(x, width) substr(x, 1L, width)
  env$data.table <- function(...) data.frame(...)

  # Existing callers still get their normal notification; quick search opts out.
  env$DBq("SELECT existing behavior")
  expect_length(notices, 1L)
  notices <- character()
  rows <- env$quick_search_db_get("WITH search_rows AS (SELECT 1)")
  expect_true("error" %in% names(rows))
  expect_length(notices, 0L)
  result <- env$quick_search_fetch("RROR", as.Date("2026-11-03"))
  expect_length(notices, 0L)
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  expect_match(html, "Not found", fixed = TRUE)
  expect_no_match(html, "WITH search_rows|synthetic unavailable source")
})


test_that("quick search accepts complete colour combinations without a dash", {
  env <- quick_search_test_env()
  expect_identical(env$quick_search_normalize_combo(" rror "), "RROR")
  expect_identical(env$quick_search_normalize_combo("RR-OR"), "RROR")
  expect_identical(env$quick_search_normalize_combo("LLLL"), "LLLL")
  for (input in list(NULL, NA_character_, "", "RRO", "RR?R", "XXXX", "RROR'", c("RROR", "BYGB"))) {
    expect_error(env$quick_search_normalize_combo(input))
  }
})


test_that("search queries bind the combo and date and select fieldwork columns", {
  env <- quick_search_test_env()
  queries <- env$quick_search_queries("RROR", as.Date("2026-11-02"))
  expect_setequal(names(queries), c(
    "CAPTURES_ARCHIVE", "CAPTURES", "RESIGHTINGS", "NESTS"
  ))
  expect_identical(queries$CAPTURES$params, list("2026-11-02", "RROR", "RROR"))
  expect_match(queries$CAPTURES$sql, "OR incoming_combo = ?", fixed = TRUE)
  expect_no_match(queries$CAPTURES$sql, "species|observer|\\bage\\b")
  expect_no_match(queries$RESIGHTINGS$sql, "species|observer|\\bage\\b|rclass|behav|gps_id|gps_point|\\bsex\\b")
  expect_match(queries$RESIGHTINGS$sql, "MIN(date) OVER () AS first_seen", fixed = TRUE)
  expect_match(queries$RESIGHTINGS$sql, "MAX(date) OVER () AS last_seen", fixed = TRUE)
  expect_match(queries$CAPTURES$sql, "LIMIT 51", fixed = TRUE)
  expect_match(queries$RESIGHTINGS$sql, "ORDER BY date DESC, pk DESC\nLIMIT 1", fixed = TRUE)
  for (query in queries) {
    expect_no_match(query$sql, "RROR", fixed = TRUE)
    expect_no_match(query$sql, "SELECT * FROM", fixed = TRUE)
    expect_no_match(query$sql, "latitude|longitude|lat,|lon,|blood_samp|nov|capture_status|comments")
  }
  for (query in queries[c("CAPTURES", "RESIGHTINGS")]) {
    expect_match(query$sql, "date <= CAST(? AS DATE) OR date IS NULL", fixed = TRUE)
  }
  expect_error(env$quick_search_queries("RROR' OR 1=1", as.Date("2026-11-02")))
})


test_that("partner queries use shared capture nests at the selected date", {
  env <- quick_search_test_env()
  query <- env$quick_search_queries("RROR", as.Date("2026-11-03"))$NESTS
  expect_identical(query$params, list("2026-11-03", "RROR", "RROR", "RROR", "RROR"))
  expect_match(query$sql, "FROM CAPTURES", fixed = TRUE)
  expect_match(query$sql, "partner.nest_id = focal.nest_id", fixed = TRUE)
  expect_match(query$sql, "partner.site = focal.site", fixed = TRUE)
  expect_match(query$sql, "partner.species = focal.species", fixed = TRUE)
  expect_no_match(query$sql, "TODO_|settings|FROM NESTS")
})


test_that("nest distance behavior runs in the browser without sending device coordinates", {
  node <- Sys.which("node")
  skip_if(!nzchar(node), "Node is not installed.")
  result <- system2(node, shQuote(app_file("tests", "quick-search-location.js")),
    stdout = TRUE, stderr = TRUE)
  expect_null(attr(result, "status"), info = paste(result, collapse = "\n"))
})


test_that("nest coordinate lookup is optional and scoped to the last nest", {
  env <- quick_search_test_env()
  refdate <- as.Date("2026-11-03")
  location <- data.frame(lat = 0, lon = 0.001)
  queries <- 0L
  db_get <- function(sql, params) {
    if (grepl("WITH band_rows AS", sql, fixed = TRUE)) {
      return(data.frame(nest_id = "MOCK01", site = "CR", species = "BADO"))
    }
    if (grepl("JOIN GPS_POINTS", sql, fixed = TRUE)) {
      queries <<- queries + 1L
      expect_identical(params, list("MOCK01", "CR", "BADO", "2026-11-03"))
      return(location)
    }
    data.frame()
  }
  result <- env$quick_search_fetch("RROR", refdate, db_get)
  expect_identical(queries, 1L)
  expect_identical(result$nest_location, list(lat = 0, lon = 0.001))
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  expect_match(html, 'data-nest-lat="0"', fixed = TRUE)
  expect_match(html, 'data-nest-lon="0.001"', fixed = TRUE)
  expect_match(html, '<th scope="row">your_dist_to_nest</th>', fixed = TRUE)
  location <- data.frame(lat = 91, lon = 0)
  expect_null(env$quick_search_fetch("RROR", refdate, db_get)$nest_location)
  location <- data.frame(error = "synthetic missing GPS table")
  result <- env$quick_search_fetch("RROR", refdate, db_get)
  expect_null(result$nest_location)
  expect_identical(result$last_nest, "MOCK01")
  expect_no_match(htmltools::renderTags(env$quick_search_results_ui(result))$html,
    "synthetic missing GPS table", fixed = TRUE)
})


test_that("search runs on the first submission and never while typing", {
  env <- quick_search_test_env()
  calls <- 0L
  env$quick_search_fetch <- function(combo, refdate) {
    calls <<- calls + 1L
    list(combo = combo, refdate = refdate, sources = list())
  }
  server <- function(input, output, session) {
    refdate <- shiny::reactiveVal(as.Date("2026-11-02"))
    search_result <- env$quick_search_server(input, output, refdate)
  }

  shiny::testServer(server, {
    session$flushReact()
    expect_null(output$quick_search_results)
    expect_identical(calls, 0L)

    session$setInputs(quick_search_combo = "RROR")
    expect_identical(calls, 0L)
    session$setInputs(quick_search_request = list(combo = "rror"))
    expect_identical(search_result()$combo, "RROR")
    expect_identical(calls, 1L)

    session$setInputs(quick_search_combo = "BYGB")
    expect_identical(search_result()$combo, "RROR")
    expect_identical(calls, 1L)

    refdate(as.Date("2026-11-01"))
    session$flushReact()
    expect_match(output$quick_search_results$html, "Date changed. Search again.", fixed = TRUE)
    expect_identical(calls, 1L)
    session$setInputs(quick_search_request = list(combo = "RR?R"))
    expect_match(output$quick_search_results$html, "Not found", fixed = TRUE)
    expect_identical(calls, 1L)

    session$setInputs(quick_search_request = list(combo = "BYGB"))
    expect_identical(search_result()$combo, "BYGB")
    expect_identical(calls, 2L)
  })
})


test_that("one failed source does not discard matches or expose database errors", {
  env <- quick_search_test_env()
  calls <- 0L
  fake_query <- function(sql, params) {
    calls <<- calls + 1L
    if (grepl("WITH first_capture_rows AS", sql, fixed = TRUE)) {
      return(data.frame(first_capture = "2024-09-01", n = 1L))
    }
    if (grepl("FROM CAPTURES_ARCHIVE\n", sql, fixed = TRUE)) {
      return(data.frame(date = "2025-10-01", ring = "MOCK001", field_sex = "F", gen_sex = "F"))
    }
    if (grepl("WITH band_rows AS", sql, fixed = TRUE)) {
      return(data.frame(
        nest_id = c("-A0203", "B0102", "A0101"),
        site = "CR", species = "BADO",
        first_seen = c("2026-09-01", "2026-10-01", "2026-11-01")
      ))
    }
    if (grepl("FROM NESTS", sql, fixed = TRUE)) {
      expect_identical(params, list("A0101", "CR", "BADO", "2026-11-02"))
      return(data.frame(date = "2026-11-02", nest_state = "I", clutch_size = 3L, brood_size = 0L))
    }
    if (grepl("FROM CAPTURES\n", sql, fixed = TRUE)) {
      return(data.frame(date = rep("2026-11-01", 51L), ring = "MOCK001"))
    }
    if (grepl("FROM RESIGHTINGS\n", sql, fixed = TRUE)) {
      return(data.frame(error = "private database diagnostic"))
    }
    data.frame(partner = NA_character_)
  }

  result <- env$quick_search_fetch("RROR", as.Date("2026-11-02"), fake_query)
  expect_identical(calls, 8L)
  expect_identical(result$nest_ids, "-A0203, B0102, A0101")
  expect_identical(result$last_nest, "A0101")
  expect_false(result$nest_visit$failed)
  expect_true(result$first_capture$found)
  expect_identical(result$first_capture$date, "2024-09-01")
  expect_equal(nrow(result$sources$CAPTURES$rows), 50L)
  expect_true(result$sources$CAPTURES$more)
  expect_true(result$sources$RESIGHTINGS$failed)
  expect_false(result$sources$NESTS$failed)
  expect_equal(nrow(result$sources$NESTS$rows), 0L)
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  expect_no_match(html, "Latest 50 records", fixed = TRUE)
  expect_no_match(html, "could not be loaded|unavailable|No partner combo found")
  expect_no_match(html, "private", fixed = TRUE)
  expect_no_match(html, "Captures|Latest field resighting|Nests|<details|quick-search-section|quick-search-site|<h3")
  expect_match(html, '<table class="quick-search-table">', fixed = TRUE)
  expect_match(html, '<th scope="col">column</th>', fixed = TRUE)
  expect_match(html, '<th scope="col">value</th>', fixed = TRUE)
  expect_match(html, '<th scope="row">first_capture</th>', fixed = TRUE)
  expect_match(html, '<td>-A0203, B0102, A0101</td>', fixed = TRUE)
  expect_match(html, '<th scope="row">last_nest_state</th>', fixed = TRUE)
  expect_match(html, '<th scope="row">last_nest_visit</th>', fixed = TRUE)
  expect_match(html, '<th scope="row">last_clutch_size</th>', fixed = TRUE)
  expect_match(html, '<th scope="row">last_brood_size</th>', fixed = TRUE)
  expect_match(html, '<td>0</td>', fixed = TRUE)
  expect_equal(length(regmatches(html, gregexpr('<th scope="row">nest_id</th>', html, fixed = TRUE))[[1L]]), 1L)
})


test_that("latest resighting and partner output stay narrow", {
  env <- quick_search_test_env()
  fake_query <- function(sql, params) {
    if (grepl("FROM RESIGHTINGS\n", sql, fixed = TRUE)) {
      return(data.frame(date = c("2026-11-03", "2026-11-02"), pk = c(2L, 1L)))
    }
    if (grepl("WITH capture_rows AS", sql, fixed = TRUE)) {
      return(data.frame(partner = c("BY-GB", "WY-YG", "BYGB"), nest_id = "SHOULD_NOT_SHOW", date = "HIDDEN_DATE"))
    }
    data.frame()
  }
  result <- env$quick_search_fetch("RROR", as.Date("2026-11-03"), fake_query)
  expect_equal(nrow(result$sources$RESIGHTINGS$rows), 1L)
  expect_identical(result$sources$RESIGHTINGS$rows$date, "2026-11-03")
  html <- htmltools::renderTags(env$quick_search_record_ui(
    result$sources$NESTS$rows, "NESTS", "RROR", result$refdate
  ))$html
  expect_match(html, "partner", fixed = TRUE)
  expect_match(html, '<td>BYGB, WYYG</td>', fixed = TRUE)
  expect_no_match(html, "BY-GB|WY-YG")
  expect_equal(length(regmatches(html, gregexpr('<th scope="row">partner</th>', html, fixed = TRUE))[[1L]]), 1L)
  expect_no_match(html, "SHOULD_NOT_SHOW|HIDDEN_DATE|Nest / brood|Observer")
  result$nest_ids <- "FIRST01, LAST01"
  combined_html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  positions <- vapply(c("nest_id", "partner", "first_seen"), function(column) {
    as.integer(regexpr(paste0('<th scope="row">', column, '</th>'), combined_html, fixed = TRUE))
  }, integer(1))
  expect_true(all(positions > 0L))
  expect_true(all(diff(positions) > 0L))

  empty <- env$quick_search_fetch("RROR", as.Date("2026-11-03"), function(...) data.frame())
  expect_false(empty$sources$NESTS$failed)
  unavailable <- env$quick_search_fetch("RROR", as.Date("2026-11-03"), function(...) stop("mock failure"))
  expect_true(unavailable$sources$NESTS$failed)
  html <- htmltools::renderTags(env$quick_search_results_ui(unavailable))$html
  expect_match(html, "Not found", fixed = TRUE)
  expect_no_match(html, "First capture information is unavailable", fixed = TRUE)
})


test_that("two-column records hide removed fields and escape retained values", {
  env <- quick_search_test_env()
  row <- data.frame(
    date = "2026-11-01", site = "CR", nest_id = "-A0203", ring = "MOCK001",
    field_sex = "FU", age = "A", capture_status = "D", tag_action = "S",
    UL = NA_character_, LL = NA_character_, UR = NA_character_, LR = NA_character_,
    UL_in = "X", LL_in = "RR", UR_in = "TO", LR_in = "R",
    incoming_combo = "RROR", release_combo = NA_character_,
    comments = "REMOVED_COMMENT", species = "BADO", observer = "MOCK_OBSERVER",
    tag_id = "<script>alert('mock')</script>", tag_type = "GEO"
  )
  html <- htmltools::renderTags(env$quick_search_record_ui(
    row, "CAPTURES", "RROR", as.Date("2026-11-03")
  ))$html
  expect_no_match(html, "-A0203|capture_status|comments|REMOVED_COMMENT")
  expect_match(html, "2026-11-01 (2 days ago)", fixed = TRUE)
  expect_match(html, '<th scope="row">capture_date</th>', fixed = TRUE)
  expect_no_match(html, '<th scope="row">date</th>', fixed = TRUE)
  expect_match(html, '<th scope="row">field_sex</th>', fixed = TRUE)
  expect_match(html, '<td>FU</td>', fixed = TRUE)
  expect_no_match(html, "gen_sex|UL_in|LL_in|UR_in|LR_in|tag_action|tag_id_in|gps_id|gps_point")
  expect_no_match(html, "Release bands", fixed = TRUE)
  expect_no_match(html, "Species|BADO|Observer|MOCK_OBSERVER|Age|quick-search-site|>CR<")
  expect_match(html, "&lt;script&gt;", fixed = TRUE)
  expect_no_match(html, "<script>", fixed = TRUE)
  expect_match(html, '<th scope="row">tag_id</th>', fixed = TRUE)
  expect_no_match(html, '<th scope="row">tag_type</th>', fixed = TRUE)
  archived_html <- htmltools::renderTags(env$quick_search_record_ui(
    row, "CAPTURES_ARCHIVE", "RROR", as.Date("2026-11-03")
  ))$html
  expect_match(archived_html, '<th scope="row">tag_id</th>', fixed = TRUE)
  expect_match(archived_html, '<th scope="row">archive_capture_date</th>', fixed = TRUE)
  expect_no_match(archived_html, '<th scope="row">date</th>', fixed = TRUE)
  expect_no_match(archived_html, '<th scope="row">tag_type</th>', fixed = TRUE)
  expect_no_match(archived_html, "gen_sex|_in|tag_action|gps_id|gps_point")

  row$behav <- "IN, SC, FC"
  row$rclass <- "R"
  row$gps_id <- 1L
  row$gps_point <- 100L
  row$LL <- "RR"
  row$LR <- "OR"
  row$first_seen <- "2026-10-01"
  row$last_seen <- "2026-11-01"
  html <- htmltools::renderTags(env$quick_search_record_ui(
    row, "RESIGHTINGS", "RROR", as.Date("2026-11-03")
  ))$html
  expect_no_match(html, "field_sex|>FU<|Sex|Female|Event|Waypoint|Age|Behaviour|Species|Bands|Observer|MOCK_OBSERVER|BADO")
  expect_match(html, '<th scope="row">first_seen</th>', fixed = TRUE)
  expect_match(html, "2026-10-01 (33 days ago)", fixed = TRUE)
  expect_match(html, '<th scope="row">last_seen</th>', fixed = TRUE)
  expect_match(html, "2026-11-01 (2 days ago)", fixed = TRUE)
  expect_match(html, "MOCK001", fixed = TRUE)
  expect_no_match(html, "-A0203|capture_status|comments|REMOVED_COMMENT")
})


test_that("combined quick-search output shows shared fields and latest capture once", {
  env <- quick_search_test_env()
  reference <- as.Date("2026-11-03")
  result <- env$quick_search_fetch("RROR", reference, function(sql, params) {
    if (grepl("FROM CAPTURES_ARCHIVE\n", sql, fixed = TRUE)) {
      return(data.frame(date = "2024-08-01", ring = "MOCKOLD", tag_id = "OLDTAG"))
    }
    if (grepl("FROM CAPTURES\n", sql, fixed = TRUE)) {
      return(data.frame(
        date = c("2026-11-02", "2026-10-01", "2026-10-01"),
        ring = "MOCKCURRENT", tag_id = "CURRENTTAG", field_sex = "F"
      ))
    }
    if (grepl("FROM RESIGHTINGS\n", sql, fixed = TRUE)) {
      return(data.frame(ring = "MOCKSIGHTING"))
    }
    data.frame()
  })
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  for (column in c("capture_date", "tag_id", "ring", "field_sex")) {
    label <- paste0('<th scope="row">', column, '</th>')
    expect_equal(length(regmatches(html, gregexpr(label, html, fixed = TRUE))[[1L]]), 1L)
  }
  expect_match(html, "2026-11-02 (1 day ago)", fixed = TRUE)
  expect_match(html, "MOCKCURRENT", fixed = TRUE)
  expect_match(html, "CURRENTTAG", fixed = TRUE)
  expect_no_match(html, "MOCKOLD|OLDTAG|MOCKSIGHTING|2026-10-01")
  result$sources$CAPTURES$rows <- data.frame()
  fallback <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  expect_match(fallback, "MOCKOLD", fixed = TRUE)
  expect_match(fallback, "OLDTAG", fixed = TRUE)
  expect_no_match(fallback, "MOCKSIGHTING")
})


test_that("missing quick-search values keep their fields visible", {
  env <- quick_search_test_env()
  reference <- as.Date("2026-11-03")
  result <- env$quick_search_fetch("RROR", reference, function(sql, params) {
    if (grepl("FROM CAPTURES_ARCHIVE\n", sql, fixed = TRUE)) {
      return(data.frame(
        date = NA_character_, ring = "MOCK001", field_sex = "NA",
        gen_sex = "", tag_id = "N/A"
      ))
    }
    data.frame()
  })
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  for (column in c(
    "first_capture", "nest_id", "partner", "last_nest_visit",
    "last_nest_state", "last_clutch_size", "last_brood_size",
    "archive_capture_date", "capture_date", "tag_id", "first_seen", "last_seen"
  )) {
    expect_match(html, paste0('<th scope="row">', column, '</th>\n',
      '        <td>—</td>'), fixed = TRUE)
  }
  expect_match(html, "MOCK001", fixed = TRUE)
  expect_match(html, '<td class="quick-search-distance">—</td>', fixed = TRUE)
  expect_no_match(html, ">NA<|>N/A<|No date|tag_type|capture_status|comments")
  expect_no_match(html, "gen_sex|UL_in|LL_in|UR_in|LR_in|tag_action|tag_id_in|gps_id|gps_point")
  capture <- htmltools::renderTags(env$quick_search_record_ui(
    data.frame(brood_size = 0L, nest_state = "NULL", hatch_state = "   "),
    "NEST_VISIT", "RROR", reference
  ))$html
  expect_match(capture, '<td>0</td>', fixed = TRUE)
  expect_no_match(capture, ">NULL<")
})


test_that("date ages use the chosen reference date and tolerate unknown dates", {
  env <- quick_search_test_env()
  reference <- as.Date("2026-11-03")
  expect_identical(env$quick_search_date_label("2026-11-03", reference), "2026-11-03 (0 days ago)")
  expect_identical(env$quick_search_date_label("2026-11-02", reference), "2026-11-02 (1 day ago)")
  expect_identical(env$quick_search_date_label("2026-11-01", reference), "2026-11-01 (2 days ago)")
  expect_identical(env$quick_search_date_label("2026-11-04", reference), "2026-11-04 (in 1 day)")
  expect_identical(env$quick_search_date_label(NA_character_, reference), "—")
  expect_identical(env$quick_search_date_label(NULL, reference), "—")
})


test_that("a missing last-nest visit does not fall back to an earlier nest", {
  env <- quick_search_test_env()
  looked_up <- character()
  db_get <- function(sql, params) {
    if (grepl("WITH band_rows AS", sql, fixed = TRUE)) {
      return(data.frame(
        nest_id = c("FIRST01", "LAST01"), site = "CR", species = "BADO",
        first_seen = c("2026-10-01", "2026-11-01")
      ))
    }
    if (grepl("FROM NESTS", sql, fixed = TRUE)) looked_up <<- c(looked_up, params[[1L]])
    data.frame()
  }
  result <- env$quick_search_fetch("RROR", as.Date("2026-11-03"), db_get)
  expect_identical(looked_up, c("LAST01", "LAST01"))
  expect_false(result$nest_visit$failed)
  expect_equal(nrow(result$nest_visit$rows), 0L)
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  expect_no_match(html, "No visit recorded|unavailable")
})


test_that("actual SQL finds shared-nest partners using synthetic MariaDB captures", {
  socket <- Sys.getenv("FIELDWORKER_QUICK_SEARCH_TEST_SOCKET", unset = "")
  skip_if(!nzchar(socket), "Disposable MariaDB fixture not started.")
  skip_if_not_installed("RMariaDB")
  env <- quick_search_test_env()
  con <- DBI::dbConnect(
    RMariaDB::MariaDB(), unix.socket = socket,
    username = "root", dbname = "quick_search_synthetic", default.file = "/dev/null"
  )
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  formatter <- paste(readLines(app_file("DATABASE", "functions.SQL")), collapse = "\n")
  formatter <- gsub("FIELD_2026_BADOatNZ.", "", formatter, fixed = TRUE)
  DBI::dbExecute(con, formatter)

  capture <- function(pk, ll, lr, ...) {
    row <- list(
      pk = as.integer(pk), date = "2026-11-01", site = "CR", species = "BADO",
      nest_id = "MOCK01", age = "A", ring = paste0("MOCK", pk),
      field_sex = "U", capture_status = "R",
      UL = "X", LL = ll, UR = "X", LR = lr,
      UL_in = "X", LL_in = NA_character_, UR_in = "X", LR_in = NA_character_,
      gps_id = NA_integer_, gps_point = NA_integer_, tag_id = NA_character_,
      tag_id_in = NA_character_, tag_type = NA_character_, tag_action = NA_character_,
      comments = NA_character_
    )
    changes <- list(...)
    row[names(changes)] <- changes
    as.data.frame(row, stringsAsFactors = FALSE)
  }
  captures <- do.call(rbind, list(
    capture(1, "RR", "OR", ring = "MOCKTARGET"),
    capture(2, "BY", "GB", ring = "MOCKPARTNER"),
    capture(3, "BY", "GB", ring = "MOCKPARTNER"),
    capture(4, "GY", "BB", nest_id = "OTHER01"),
    capture(5, "GY", "BB", site = "AR"),
    capture(6, "GY", "BB", species = "WRYB"),
    capture(7, "GY", "BB", age = "C"),
    capture(8, "GY", "BB", ring = "MOCKTARGET", LL_in = "RR", LR_in = "OR"),
    capture(9, "GY", "BB", date = "2026-11-04"),
    capture(10, "GY", "BB", nest_id = NA_character_),
    capture(11, NA_character_, NA_character_, UL = NA_character_, UR = NA_character_,
      capture_status = "D", LL_in = "WY", LR_in = "YG"),
    capture(12, "X", "X", UL = "FWAB"),
    capture(13, "OY", "R", UR = "TB")
  ))
  captures <- rbind(
    captures,
    do.call(rbind, lapply(101:155, function(pk) capture(pk, "RR", "OR", ring = "MOCKTARGET"))),
    capture(999, "RR", "OR", ring = "MOCKTARGET", nest_id = "OLDEST01", date = "2026-08-01")
  )
  captures$date <- as.Date(captures$date)
  DBI::dbWriteTable(con, "CAPTURES", captures, overwrite = TRUE)
  archive <- data.frame(
    date = as.Date(c("2025-10-01", "2024-09-01", "2020-01-01", "2027-01-01", "2023-08-01", "2019-01-01")),
    ring = c("MOCKTARGET", "mock-target", "MOCKOTHER", "MOCKFUTURE", "MOCKARCHONLY", "NA"),
    UL = "X", LL = c("RR", "GY", "BY", "RR", "LL", "GY"),
    UR = "X", LR = c("OR", "BB", "GB", "OR", "OW", "BB"),
    field_sex = c("M", "M", "F", "M", "F", "U"),
    gen_sex = c("M", "M", "F", NA, "F", NA),
    tag_id = c(NA, NA, NA, NA, "MOCKTAG", NA),
    tag_type = c(NA, NA, NA, NA, "GEO", NA)
  )
  DBI::dbWriteTable(con, "CAPTURES_ARCHIVE", archive, overwrite = TRUE)
  sightings <- data.frame(
    pk = seq_len(6),
    date = as.Date(c("2026-09-01", "2026-10-01", "2026-11-02", "2026-11-04", "2026-11-02", NA)),
    site = "CR", species = "BADO", ring = "MOCKTARGET",
    nest_id = c("EARLY01", "MOCK01", "MOCK01", "FUTURE01", "LATE01", "UNDATED01"),
    comments = c("first", "earlier", "recent", "future", "latest same-day row", "undated"),
    UL = "X", LL = "RR", UR = "X", LR = "OR"
  )
  DBI::dbWriteTable(con, "RESIGHTINGS", sightings, overwrite = TRUE)
  sighting_only <- sightings[1L, , drop = FALSE]
  sighting_only$pk <- 20L
  sighting_only$date <- as.Date("2026-11-02")
  sighting_only$ring <- "MOCKSIGHT"
  sighting_only$nest_id <- "MOCK01"
  sighting_only$LL <- "WW"
  sighting_only$LR <- "GG"
  DBI::dbAppendTable(con, "RESIGHTINGS", sighting_only)
  visits <- data.frame(
    pk = seq_len(9), nest_id = c(rep("UNDATED01", 7), "MOCK01", "UNDATED01"),
    site = c(rep("CR", 5), "AR", "CR", "CR", "CR"),
    species = c(rep("BADO", 6), "WRYB", "BADO", "BADO"),
    date = as.Date(c("2026-11-01", rep("2026-11-02", 3), "2026-11-04", rep("2026-11-03", 3), NA)),
    time_visit = c("08:00:00", "09:00:00", "10:00:00", "10:00:00", rep("12:00:00", 5)),
    nest_state = c("I", "H", "H", "H", "P", "D", "D", "D", "O"),
    hatch_state = "4N", bird_inc = "F", clutch_size = c(4L, rep(0L, 8)),
    brood_size = c(0L, 1L, 2L, 3L, rep(0L, 5))
  )
  visits$gps_id <- 1L
  visits$gps_point <- seq_len(nrow(visits))
  visits$nest_state[c(1L, 5L, 6L, 7L)] <- "S"
  visits$nest_state[2L] <- "F"
  DBI::dbWriteTable(con, "NESTS", visits, overwrite = TRUE)
  points <- data.frame(
    pk = seq_len(10), gps_id = c(rep(1L, 9), 2L),
    gps_point = c(seq_len(9), 1L),
    lat = seq_len(10) / 100, lon = seq_len(10) / 100,
    datetime_ = c(rep("2026-11-01 08:00:00", 9), "2026-10-01 08:00:00")
  )
  DBI::dbWriteTable(con, "GPS_POINTS", points, overwrite = TRUE)
  db_get <- function(sql, params) DBI::dbGetQuery(con, sql, params = params)
  coordinates <- env$quick_search_nest_location_query("UNDATED01", "CR", "BADO", as.Date("2026-11-03"))
  selected <- db_get(coordinates$sql, coordinates$params)
  expect_equal(selected$lat, 0.01)
  expect_equal(selected$lon, 0.01)
  coordinates <- env$quick_search_nest_location_query("UNDATED01", "CR", "BADO", as.Date("2026-10-31"))
  expect_equal(nrow(db_get(coordinates$sql, coordinates$params)), 0L)
  nest_query <- env$quick_search_nest_query("RROR", as.Date("2026-11-03"))
  nest_history <- db_get(nest_query$sql, nest_query$params)
  expect_equal(nrow(nest_history), 5L)
  result <- env$quick_search_fetch("RROR", as.Date("2026-11-03"), db_get)
  expect_false(any(vapply(result$sources, function(source) source$failed, logical(1))))
  expect_setequal(result$sources$NESTS$rows$partner, c("BY-GB", "WY-YG", "FWAB-X", "OY-BR"))
  expect_equal(nrow(result$sources$NESTS$rows), 4L)
  expect_true(result$sources$CAPTURES$more)
  expect_identical(result$nest_ids, "OLDEST01, EARLY01, MOCK01, LATE01, UNDATED01")
  expect_false(result$nests_failed)
  expect_true(result$first_capture$found)
  expect_false(result$first_capture$failed)
  expect_identical(as.character(result$first_capture$date), "2024-09-01")
  expect_identical(result$last_nest, "UNDATED01")
  expect_equal(result$nest_location, list(lat = 0.01, lon = 0.01))
  expect_false(result$nest_visit$failed)
  expect_equal(nrow(result$nest_visit$rows), 1L)
  expect_identical(result$nest_visit$rows$nest_state, "H")
  expect_identical(result$nest_visit$rows$brood_size, 3L)
  expect_identical(as.character(result$nest_visit$rows$date), "2026-11-02")
  latest <- result$sources$RESIGHTINGS$rows
  expect_equal(nrow(latest), 1L)
  expect_identical(latest$pk, 5L)
  expect_false("comments" %in% names(latest))
  expect_identical(as.character(latest$first_seen), "2026-09-01")
  expect_identical(as.character(latest$last_seen), "2026-11-02")

  without_capture <- env$quick_search_fetch("WWGG", as.Date("2026-11-03"), db_get)
  expect_equal(nrow(without_capture$sources$CAPTURES$rows), 0L)
  expect_false(without_capture$sources$NESTS$failed)
  expect_true(all(c("RR-OR", "BY-GB") %in% without_capture$sources$NESTS$rows$partner))
  expect_false("WW-GG" %in% without_capture$sources$NESTS$rows$partner)
  without_capture_html <- htmltools::renderTags(env$quick_search_results_ui(without_capture))$html
  expect_match(without_capture_html, '<th scope="row">partner</th>', fixed = TRUE)
  expect_match(without_capture_html, "BYGB", fixed = TRUE)

  no_matches <- env$quick_search_fetch("LLLL", as.Date("2026-11-03"), db_get)
  expect_false(no_matches$sources$NESTS$failed)
  expect_equal(nrow(no_matches$sources$NESTS$rows), 0L)
  expect_false(no_matches$first_capture$found)
  archive_only <- env$quick_search_fetch("LLOW", as.Date("2026-11-03"), db_get)
  expect_true(archive_only$first_capture$found)
  expect_false(archive_only$sources$CAPTURES_ARCHIVE$failed)
  expect_identical(as.character(archive_only$first_capture$date), "2023-08-01")
  archive_html <- htmltools::renderTags(env$quick_search_results_ui(archive_only))$html
  expect_match(archive_html, "2023-08-01", fixed = TRUE)
  expect_match(archive_html, "MOCKARCHONLY", fixed = TRUE)
  expect_no_match(archive_html, '<th scope="row">gen_sex</th>', fixed = TRUE)
  expect_match(archive_html, "MOCKTAG", fixed = TRUE)
  expect_no_match(archive_html, "No partner|unavailable|could not be loaded|CAPTURES_ARCHIVE|Historical captures")
  expect_no_match(archive_html, "No exact matches.", fixed = TRUE)
  html <- htmltools::renderTags(env$quick_search_results_ui(result))$html
  expect_match(html, '<td>BYGB, FWABX, OYBR, WYYG</td>', fixed = TRUE)
  expect_equal(length(regmatches(html, gregexpr('<th scope="row">partner</th>', html, fixed = TRUE))[[1L]]), 1L)
  expect_match(html, '<th scope="row">first_capture</th>', fixed = TRUE)
  expect_match(html, "2024-09-01", fixed = TRUE)
  expect_match(html, "2026-11-02 (1 day ago)", fixed = TRUE)
  expect_match(html, '<th scope="row">last_nest_state</th>', fixed = TRUE)
  expect_match(html, '<th scope="row">last_brood_size</th>', fixed = TRUE)
  expect_no_match(html, "snapshot|TODO_|Captures|Nests")
  before_archive <- env$quick_search_first_capture_query("RROR", as.Date("2024-01-01"))
  before_rows <- db_get(before_archive$sql, before_archive$params)
  expect_equal(as.numeric(before_rows$n), 0)
  expect_true(is.na(before_rows$first_capture))

  DBI::dbExecute(con, "RENAME TABLE CAPTURES_ARCHIVE TO ARCHIVE_HIDDEN_FOR_TEST")
  current_only <- env$quick_search_fetch("RROR", as.Date("2026-11-03"), db_get)
  expect_true(current_only$sources$CAPTURES_ARCHIVE$failed)
  expect_true(current_only$first_capture$found)
  expect_identical(as.character(current_only$first_capture$date), "2026-08-01")
  current_html <- htmltools::renderTags(env$quick_search_results_ui(current_only))$html
  expect_no_match(current_html, "unavailable|could not be loaded")
  DBI::dbExecute(con, "RENAME TABLE ARCHIVE_HIDDEN_FOR_TEST TO CAPTURES_ARCHIVE")

  DBI::dbRemoveTable(con, "CAPTURES")
  DBI::dbRemoveTable(con, "RESIGHTINGS")
  DBI::dbRemoveTable(con, "NESTS")
  standalone <- env$quick_search_fetch("LLOW", as.Date("2026-11-03"), db_get)
  expect_false(standalone$sources$CAPTURES_ARCHIVE$failed)
  expect_true(standalone$sources$CAPTURES$failed)
  expect_true(standalone$sources$RESIGHTINGS$failed)
  expect_true(standalone$first_capture$found)
  expect_identical(as.character(standalone$first_capture$date), "2023-08-01")
  standalone_html <- htmltools::renderTags(env$quick_search_results_ui(standalone))$html
  expect_match(standalone_html, "MOCKARCHONLY", fixed = TRUE)
  expect_match(standalone_html, "MOCKTAG", fixed = TRUE)
  expect_match(standalone_html, "2023-08-01", fixed = TRUE)
  expect_no_match(standalone_html, "unavailable|could not be loaded|No exact matches|No partner")
  DBI::dbRemoveTable(con, "CAPTURES_ARCHIVE")
  missing <- env$quick_search_fetch("LLOW", as.Date("2026-11-03"), db_get)
  missing_html <- htmltools::renderTags(env$quick_search_results_ui(missing))$html
  expect_match(missing_html, "Not found", fixed = TRUE)
})
