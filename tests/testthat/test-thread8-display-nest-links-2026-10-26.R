# Invented inputs only. Source helper definitions without main/global.R or config.
thread8_display_env <- function() {
  env <- new.env(parent = asNamespace("data.table"))
  env$glue <- glue::glue
  env$st_as_sf <- sf::st_as_sf
  env$st_transform <- sf::st_transform
  env$DBq <- env$db_get <- function(...) stop("Database access forbidden in display tests")
  for (name in c(
    "display_nest_ids.R", "leaflet_nest_latest.R", "pdf_todo.R",
    "pdf_todo_map.R", "ggplot_overview.R"
  )) {
    path <- testthat::test_path("..", "..", "main", "R", name)
    sys.source(path, envir = env)
  }
  env
}

thread8_display_ids <- c(
  " A0001 ", "-B0002", "BA0003", NA, "", "   ",
  "NO_NEST", " no_nest ", "No_Nest", "NA", " null ", "N/A"
)

test_that("live map never promotes historical non-links into nests or broods", {
  env <- thread8_display_env()
  input <- data.table::data.table(
    nest_id = thread8_display_ids, nest_state = "H", has_hatch_evidence = TRUE
  )
  before <- data.table::copy(input)
  mapped <- env$.prepare_live_nest_map_data(input, input)
  expect_setequal(mapped$nest_id, c("A0001", "-B0002", "BA0003"))
  expect_true(all(mapped$map_category == "brood"))
  expect_identical(input, before)
})

test_that("PDF chick identities and latest counts require a real link", {
  env <- thread8_display_env()
  captures <- data.table::data.table(
    nest_id = thread8_display_ids, ring = paste0("MOCK", seq_along(thread8_display_ids)),
    date = as.Date("2026-10-20"), source = "capture", age = "C", LL = "R", LR = "M"
  )
  before <- data.table::copy(captures)
  context <- data.table::data.table(
    nest_id = c("A0001", "-B0002", "BA0003"),
    latest_encounter_date = as.Date("2026-10-20"),
    latest_encounter_count = 1L,
    latest_encounter_flagged_count = 0L,
    latest_encounter_unflagged_count = 1L,
    latest_encounter_availability = "available"
  )
  expect_setequal(
    env$todo_pdf_latest_chick_encounter_counts_from_context(context)$nest_id,
    c("A0001", "-B0002", "BA0003")
  )
  expect_setequal(
    env$todo_pdf_captured_chick_ring_lists(captures)$nest_id,
    c("A0001", "-B0002", "BA0003")
  )
  expect_setequal(
    env$.todo_pdf_map_prepare_chick_bands(captures, as.Date("2026-10-26"))$nest_id,
    c("A0001", "-B0002", "BA0003")
  )
  expect_identical(captures, before)
})

test_that("PDF nest summary excludes non-links while retaining known parents", {
  env <- thread8_display_env()
  nests <- data.table::data.table(
    nest_id = thread8_display_ids, nest_state = "I", min_days_to_hatch = 8,
    M_mark = "MOCK-M", F_mark = "MOCK-F"
  )
  summary <- env$todo_pdf_prepare_nest_summary(nests, as.Date("2026-10-26"))
  expect_setequal(summary$Nest, c("A0001", "-B0002", "BA0003"))
  expect_true(all(summary$Male == "MOCK-M"))
  expect_true(all(summary$Female == "MOCK-F"))
})

test_that("Overview lay-date counts do not count historical non-links as nests", {
  env <- thread8_display_env()
  bins <- env$overview_lay_date_bins(data.table::data.table(
    nest_id = thread8_display_ids, datetime = as.Date("2026-10-20")
  ))
  expect_equal(sum(bins$n_nests), 3L)
})

test_that("separate encounters retain changed brood links and ring identities", {
  env <- thread8_display_env()
  context <- data.table::data.table(
    nest_id = c("-B0002", "A0001"),
    latest_encounter_date = as.Date(c("2026-10-19", "2026-10-20")),
    latest_encounter_count = c(1L, 2L),
    latest_encounter_flagged_count = c(0L, 1L),
    latest_encounter_unflagged_count = c(1L, 1L),
    latest_encounter_availability = c("available", "available"),
    latest_encounter_ring_list = c("MOCK1", "MOCK1, MOCK2")
  )
  counts <- env$todo_pdf_latest_chick_encounter_counts_from_context(context)
  expect_equal(counts[nest_id == "-B0002", latest_chick_count], 1L)
  expect_equal(counts[nest_id == "A0001", latest_chick_count], 2L)
  expect_identical(counts[nest_id == "A0001", latest_chick_ring_list], "MOCK1, MOCK2")
})

test_that("PDF source no longer contains a competing raw chick resolver", {
  env <- thread8_display_env()
  expect_false(exists("todo_pdf_chick_event_context_sql", envir = env, inherits = FALSE))
  expect_false(exists("todo_pdf_latest_chick_encounter_counts", envir = env, inherits = FALSE))
})

test_that("PDF tasks keep labels, notes and selected parent identities for valid links", {
  env <- thread8_display_env()
  todo <- data.table::data.table(
    nest_id = thread8_display_ids, reference_date = as.Date("2026-10-26"),
    todo = "Parent capture", notes = "deploy GEO only when eligible",
    nest_state = "I", clutch_size = 3, brood_size = 0,
    M_mark = "MOCK-OLD-M", F_mark = "MOCK-OLD-F",
    authoritative_M_mark = "MOCK-M", authoritative_F_mark = "MOCK-F"
  )
  before <- data.table::copy(todo)
  result <- env$todo_pdf_prepare(todo, available_combos = data.frame(mark = "MOCK-MARK"))
  expect_setequal(trimws(result$rows$Nest), c("A0001", "-B0002", "BA0003"))
  expect_true(all(result$rows$Todo == "Parent capture"))
  expect_true(all(result$rows$Notes == "deploy GEO only when eligible"))
  expect_true(all(result$rows$Male == "MOCK-M"))
  expect_true(all(result$rows$Female == "MOCK-F"))
  expect_identical(todo, before)
})

test_that("PDF map rejects non-links from both tasks and latest positions", {
  env <- thread8_display_env()
  ids <- c("A0001", "-B0002", "BA0003", "NO_NEST", " no_nest ", "NA", " null ", "N/A")
  # Coordinates are invented, at the origin, solely for in-memory geometry.
  todo <- data.table::data.table(
    nest_id = ids, reference_date = as.Date("2026-10-26"),
    todo = "Parent capture", notes = "capture", lat = 0, lon = 0
  )
  positions <- data.table::data.table(nest_id = ids, nest_state = "I", lat = 0, lon = 0)
  mapped <- env$.todo_pdf_map_prepare_nests(todo, nests_latest = positions)
  expect_setequal(mapped$nest_id, c("A0001", "-B0002", "BA0003"))
  expect_true(all(as.character(mapped$parent_work) == "Capture"))
  expect_true(all(as.character(mapped$check_type) == "Other task"))
})

test_that("direct live-map callers also reject non-links", {
  env <- thread8_display_env()
  for (pkg in c("leaflet", "htmlwidgets", "htmltools", "sf", "glue")) {
    for (name in getNamespaceExports(pkg)) env[[name]] <- getExportedValue(pkg, name)
  }
  env$nest_state_cols <- c(I = "#111111")
  map <- env$live_nest_leaflet(
    data.table::data.table(nest_id = thread8_display_ids, nest_state = "I", lat = 0, lon = 0),
    plots = data.frame()
  )
  # A leaflet widget is built in memory; no browser or tile request is made.
  methods <- vapply(map$x$calls, `[[`, character(1), "method")
  markers <- map$x$calls[[match("addCircleMarkers", methods)]]
  expect_length(markers$args[[1]], 3L)
})

test_that("a filtered PDF still retains its supplied reference date", {
  env <- thread8_display_env()
  todo <- data.table::data.table(
    nest_id = "NO_NEST", reference_date = as.Date("2026-10-26"),
    todo = "Parent capture", notes = "capture", nest_state = "I",
    clutch_size = 3, brood_size = 0, M_mark = "MOCK-M", F_mark = "MOCK-F"
  )
  result <- env$todo_pdf_prepare(todo, available_combos = data.frame(mark = "MOCK-MARK"))
  expect_equal(nrow(result$rows), 0L)
  expect_identical(as.character(result$title), "Cass To-Dos for 2026-10-26")
})
