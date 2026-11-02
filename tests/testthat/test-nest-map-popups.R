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

test_that("cached association displays match nest, date, and current identity", {
  env <- popup_test_env()
  points <- data.table::data.table(
    nest_id = c("MOCK-OK", "MOCK-OLD", "MOCK-NEW-BIRD", "MOCK-DUP"),
    reference_date = as.Date("2026-11-02"), M_mark = "MOCK-M", F_mark = "MOCK-F"
  )
  parents <- data.table::data.table(
    nest_id = c("MOCK-OK", "MOCK-OLD", "MOCK-NEW-BIRD", "MOCK-DUP", "MOCK-DUP"),
    reference_date = as.Date(c("2026-11-02", "2026-11-01", "2026-11-02", "2026-11-02", "2026-11-02")),
    M_parent_mark = c("MOCK-M", "MOCK-M", "OTHER-M", "MOCK-M", "MOCK-M"),
    F_parent_mark = "MOCK-F", M_association_display = "MOCK-M (2)",
    F_association_display = "MOCK-F (IN)"
  )
  before <- data.table::copy(points)
  result <- env$.nest_map_add_parent_associations(points, parents)
  popup <- env$.nest_map_popups(result)
  expect_match(popup[1], "<th>Male</th><td>MOCK-M (2)</td>", fixed = TRUE)
  expect_match(popup[1], "<th>Female</th><td>MOCK-F (IN)</td>", fixed = TRUE)
  expect_false(grepl("MOCK-M (2)", popup[2], fixed = TRUE))
  expect_false(grepl("MOCK-M (2)", popup[3], fixed = TRUE))
  expect_false(grepl("MOCK-M (2)", popup[4], fixed = TRUE))
  expect_match(popup[3], "MOCK-F (IN)", fixed = TRUE)
  expect_identical(points, before)
  expect_identical(env$.nest_map_add_parent_associations(points, parents[, !"M_association_display"]), points)
  expect_identical(env$.nest_map_add_parent_associations(points, data.frame(error = "unavailable")), points)
  parents <- parents[1]
  parents[, M_parent_mark := "MOCK-M & MOCK-OTHER"]
  parents[, M_association_display := "MOCK-M (2) & MOCK-OTHER (MM, 1)"]
  popup <- env$.nest_map_popups(env$.nest_map_add_parent_associations(points, parents))
  expect_match(popup[1], "MOCK-M (2) &amp; MOCK-OTHER (MM, 1)", fixed = TRUE)
  parents[, `:=`(M_parent_mark = "MOCK-COMPETITOR", M_selected_mark = "MOCK-M",
                 M_association_display = "MOCK-M (TN)")]
  popup <- env$.nest_map_popups(env$.nest_map_add_parent_associations(points, parents))
  expect_match(popup[1], "MOCK-M (TN)", fixed = TRUE)
  expect_false(grepl("MOCK-COMPETITOR", popup[1], fixed = TRUE))
})

test_that("map reads published snapshot metadata rather than expanding live associations", {
  env <- popup_test_env()
  sql <- env$.nest_map_parent_status_query()
  expect_match(sql, "FROM TODO_PARENT_STATUS_SNAPSHOT", fixed = TRUE)
  expect_match(sql, "ORDER BY refresh_id DESC LIMIT 1", fixed = TRUE)
  expect_match(sql, "published.state = 'succeeded'", fixed = TRUE)
  expect_match(sql, "snapshot_rows.reference_date = settings.value", fixed = TRUE)
  expect_false(grepl("ADULT_PARENT|CAPTURES|RESIGHTINGS", sql))
  task_sql <- env$.nest_map_snapshot_query("TODO_LIST_SNAPSHOT")
  expect_match(task_sql, "FROM TODO_LIST_SNAPSHOT", fixed = TRUE)
  expect_error(env$.nest_map_snapshot_query("ADULT_PARENT_STATUS"))
})

popup_hatch_test_env <- function() {
  env <- popup_test_env()
  for (file in c("display_nest_ids.R", "pdf_todo.R", "pdf_todo_map.R")) {
    sys.source(testthat::test_path("..", "..", "main", "R", file), env)
  }
  env
}

test_that("map hatch timing reuses PDF summary values for nests and broods", {
  env <- popup_hatch_test_env()
  points <- data.table::data.table(
    nest_id = c("MOCK-ACTIVE", "MOCK-OVERDUE", "MOCK-HATCHED", "-MOCK-BROOD"),
    reference_date = as.Date("2026-11-02"),
    nest_state = c("I", "I", "H", NA), map_category = c("I", "I", "brood", "brood"),
    has_hatch_evidence = c(FALSE, FALSE, TRUE, TRUE), is_negative_brood = c(FALSE, FALSE, FALSE, TRUE),
    hatch_evidence_date = as.Date(c(NA, NA, "2026-10-29", NA)),
    discovery_date = as.Date(c(NA, NA, NA, "2026-10-23")),
    min_days_to_hatch = c(6, -2, 99, NA), M_mark = "MOCK-M", F_mark = "MOCK-F"
  )
  tasks <- data.table::data.table(
    nest_id = "MOCK-HATCHED", reference_date = as.Date("2026-11-02"),
    todo = "Parent resighting", min_days_to_hatch = -5, M_mark = "MOCK-M", F_mark = "MOCK-F"
  )
  before <- data.table::copy(points)
  expected <- env$todo_pdf_prepare_nest_summary(data.table::copy(points), as.Date("2026-11-02"), todo = tasks)
  result <- env$.nest_map_add_hatch_timing(points, tasks, data.table::data.table())
  expect_identical(result$hatch_timing, c("6", "-2", "-5", "-10"))
  expect_identical(result$hatch_timing, expected[["Est. Hatch"]][match(points$nest_id, expected$Nest)])
  expect_identical(points, before)
  popup <- env$.nest_map_popups(result)
  expect_match(popup[1], "<th>Hatch timing (days)</th><td>6</td>", fixed = TRUE)
  expect_match(popup[3], "<th>Hatch timing (days)</th><td>-5</td>", fixed = TRUE)
  # A task from another reference date cannot override the live map date.
  tasks[, reference_date := as.Date("2026-11-01")]
  result <- env$.nest_map_add_hatch_timing(points, tasks, data.table::data.table())
  expect_identical(result$hatch_timing[3], "-4")
})

test_that("map retains the PDF flotation safeguards and handles unavailable estimates", {
  env <- popup_hatch_test_env()
  points <- data.table::data.table(
    nest_id = c("MOCK-NO-FLOAT", "MOCK-EXEMPT", "MOCK-UNKNOWN"),
    reference_date = as.Date("2026-11-02"), nest_state = "I",
    min_days_to_hatch = c(6, 7, NA_real_), M_mark = "MOCK-M", F_mark = "MOCK-F"
  )
  prediction <- data.table::data.table(
    nest_id = c("MOCK-NO-FLOAT", "MOCK-EXEMPT"), reference_date = as.Date("2026-11-02"),
    calibration_match_type = c("complete clutch chronology", "found as incomplete"),
    float_date = as.Date(NA), days_to_hatch = c(6, 7)
  )
  result <- env$.nest_map_add_hatch_timing(points, data.table::data.table(), prediction)
  expect_identical(result$hatch_timing, c("Unknown", "7", "Unknown"))
  result <- env$.nest_map_add_hatch_timing(points, data.frame(error = "unavailable"), prediction)
  expect_true(all(result$hatch_timing == "Unknown"))
  expect_equal(nrow(env$.nest_map_add_hatch_timing(points[0], NULL, NULL)), 0L)
})
