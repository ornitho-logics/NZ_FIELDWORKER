# Pure display checks with invented inputs; never load app/config or a database.
popup_test_env <- function() {
  env <- new.env(parent = asNamespace("data.table"))
  env$glue <- glue::glue
  env$glue_collapse <- glue::glue_collapse
  env$htmlEscape <- htmltools::htmlEscape
  env$DBq <- function(...) stop("Database access forbidden in popup tests")
  sys.source(testthat::test_path("..", "..", "main", "R", "leaflet_nest_latest.R"), env)
  env
}

test_that("last encounter uses nest visits or canonical brood encounters", {
  env <- popup_test_env()
  input <- data.table::data.table(
    nest_id = c("MOCK-NEST", "MOCK-BROOD", "-MOCK-BROOD"),
    map_category = c("I", "brood", "brood"),
    reference_date = as.Date("2026-11-02"),
    last_visit_datetime = c("2026-10-31 10:00:00", "2026-10-20 12:00:00", NA),
    latest_encounter_date = as.Date(c("2026-10-25", "2026-11-01", "2026-11-02")),
    days_ago = c(2L, 13L, NA_integer_)
  )
  before <- data.table::copy(input)
  popup <- env$.nest_map_popups(input)
  expect_match(popup[1], "<th>Last encounter</th><td>2 days ago</td>", fixed = TRUE)
  expect_match(popup[2], "<th>Last encounter</th><td>1 day ago</td>", fixed = TRUE)
  expect_match(popup[3], "<th>Last encounter</th><td>today</td>", fixed = TRUE)
  expect_identical(input, before)
  # Changing the reference date, not the computer clock, changes elapsed days.
  input[, reference_date := reference_date + 1L]
  expect_match(env$.nest_map_popups(input)[2], "<td>2 days ago</td>", fixed = TRUE)
})

test_that("missing or future brood dates never fall back to nest visits", {
  env <- popup_test_env()
  input <- data.table::data.table(
    nest_id = c("MOCK-MISSING", "MOCK-FUTURE", "MOCK-NO-REFERENCE"),
    map_category = "brood",
    reference_date = as.Date(c("2026-11-02", "2026-11-02", NA)),
    last_visit_datetime = "2026-11-01 08:00:00",
    latest_encounter_date = as.Date(c(NA, "2026-11-03", "2026-11-01")),
    days_ago = 1L
  )
  expect_true(all(grepl("<th>Last encounter</th><td>Unknown</td>",
                       env$.nest_map_popups(input), fixed = TRUE)))
  expect_length(env$.nest_map_popups(input[0]), 0L)
})

test_that("popup shows only agreed fields with readable labels and escaped values", {
  env <- popup_test_env()
  input <- data.table::data.table(
    nest_id = "MOCK-NEST", map_category = "I", nest_state = "I",
    M_mark = "<MOCK-M>", F_mark = "MOCK-F", hatch_state = "3N",
    clutch_size = 3L, brood_size = 0L, last_observer = "AB",
    reference_date = "2026-11-02", last_visit_datetime = "2026-10-31 10:00:00",
    is_negative_brood = FALSE, has_hatch_evidence = FALSE,
    latest_encounter_date = "2026-10-31", latest_chick_event_date = NA_character_,
    location_source = "MOCK-SOURCE", location_event_date = "2026-10-31",
    location_source_table = "MOCK-TABLE", days_ago = 2L,
    unrelated_metadata = "MUST-NOT-APPEAR"
  )
  popup <- env$.nest_map_popups(input)
  labels <- regmatches(popup, gregexpr("(?<=<th>).*?(?=</th>)", popup, perl = TRUE))[[1]]
  expect_identical(labels, c("Nest / brood", "State", "Male", "Female", "Hatching status",
                            "Clutch size", "Brood size", "Last encounter", "Last observer"))
  expect_match(popup, "&lt;MOCK-M&gt;", fixed = TRUE)
  expect_match(popup, "<th>Brood size</th><td>0</td>", fixed = TRUE)
  expect_false(grepl("MOCK-SOURCE|MOCK-TABLE|MUST-NOT-APPEAR|days_ago|nest_state", popup))
  input[, c("F_mark", "last_observer") := list(NA_character_, "")]
  popup <- env$.nest_map_popups(input)
  expect_false(grepl("<th>Female</th>|<th>Last observer</th>", popup))
})

test_that("prepared nest and brood dates reach the actual map popup", {
  env <- popup_test_env()
  for (pkg in c("leaflet", "htmlwidgets", "htmltools", "sf", "glue")) {
    for (name in getNamespaceExports(pkg)) env[[name]] <- getExportedValue(pkg, name)
  }
  sys.source(testthat::test_path("..", "..", "main", "R", "display_nest_ids.R"), env)
  env$nest_state_cols <- c(I = "#111111", brood = "#222222")
  nests <- data.table::data.table(
    nest_id = c("MOCK-NEST", "MOCK-BROOD"), nest_state = c("I", "H"),
    reference_date = as.Date("2026-11-02"),
    last_visit_datetime = c("2026-10-31 12:00:00", "2026-10-20 12:00:00"),
    last_observer = "AB", lat = 0, lon = 0
  )
  broods <- data.table::data.table(
    nest_id = "MOCK-BROOD", nest_state = "H", has_hatch_evidence = TRUE,
    reference_date = as.Date("2026-11-02"),
    latest_encounter_date = as.Date("2026-11-01"), lat = 0, lon = 0
  )
  prepared <- env$.prepare_live_nest_map_data(nests, broods)
  popup <- env$.nest_map_popups(prepared)
  expect_match(popup[prepared$nest_id == "MOCK-NEST"], "2 days ago", fixed = TRUE)
  expect_match(popup[prepared$nest_id == "MOCK-BROOD"], "1 day ago", fixed = TRUE)
  # No observer for the brood encounter is supplied by BROODS_LATEST. Do not
  # silently relabel the old nest visitor as the latest brood observer.
  expect_false(grepl("Last observer", popup[prepared$nest_id == "MOCK-BROOD"], fixed = TRUE))
  # In-memory widget construction makes no browser or map-tile request.
  map <- env$live_nest_leaflet(prepared, plots = data.frame(), map_data_prepared = TRUE)
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  markers <- map$x$calls[[match("addCircleMarkers", methods)]]
  text <- paste(unlist(markers$args), collapse = "\n")
  expect_match(text, "<th>Last encounter</th><td>2 days ago</td>", fixed = TRUE)
  expect_match(text, "<th>Last encounter</th><td>1 day ago</td>", fixed = TRUE)
})
