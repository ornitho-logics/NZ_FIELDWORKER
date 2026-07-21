#+ NOTE:
#' list.files('./main/R/', full.names = TRUE) |> lapply(source) |> invisible(); source('main/global.R')
#' devmode(TRUE);runApp("./main", launch.browser = TRUE )

#! PACKAGES & DATA
sapply(
  c(
    "DataEntry",
    "DBI",
    "DT",
    "data.table",
    "stringr",
    "glue",
    "ggplot2",
    "htmltools",
    "htmlwidgets",
    "ini",
    "jsonlite",
    "quarto",
    "sf",
    "zip",

    "shiny",
    "shinyWidgets",
    "shinycssloaders",
    "bs4Dash",
    "fresh",
    "later",
    "waiter",

    "leaflet"
  ),
  require,
  character.only = TRUE,
  quietly = TRUE
)


#! OPTIONS

group <- "nz_fieldworker"
preferred_timezone <- "Pacific/Auckland"

db <- "FIELD_2026_BADOatNZ"
dbtabs_entry <- c(
  "OBSERVERS",
  "CAPTURES",
  "NESTS",
  "EGGS",
  "RESIGHTINGS",
  "RESIGHTINGS_PUBLIC",
  "spatial_objects",
  "inspectors"
)


dbtabs_show_tables <- c(
  "OBSERVERS",
  "CAPTURES",
  "NESTS",
  "EGGS",
  "RESIGHTINGS",
  "RESIGHTINGS_PUBLIC",
  "GPS_POINTS",
  "GPS_TRACKS",
  "settings",
  "predict_hatching"
)


dbtabs_show_views <- c(
  "TODO_LIST",
  "NESTS_LATEST",
  "CAPTURES_ARCHIVE",
  "EGGS_HATCH_PREDICTION"
)

# watch list for View updates
dbtabs_show_view_sources <- list(
  TODO_LIST = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching",
    "RESIGHTINGS"
  ),

  NESTS_LATEST = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching"
  ),
  CAPTURES_ARCHIVE = c("BADOatNZ.CAPTURES"),

  EGGS_HATCH_PREDICTION = c(
    "settings",
    "EGGS",
    "predict_hatching"
  )
)


nest_state_cols <- c(
  "S" = "#f38c38",
  "F" = "#00815f",
  "I" = "#fff023",
  "H" = "#1aa9fc",
  "B" = "#20A387",
  "pP" = "#A50026",
  "P" = "#6405a3",
  "pD" = "#CC79A7",
  "D" = "#6A51A3",
  "notA" = "#4b4b4b",
  "O" = "#999999"
)


kmz_nest_state_cols <- c(
  S = "#f7b267",
  F = "#65cdaa",
  I = "#fff58f",
  H = "#78d6ff",
  B = "#76d7bd",
  pP = "#e37882",
  P = "#b78be7",
  pD = "#edadd3",
  D = "#b9a1dc",
  notA = "#9b9b9b",
  O = "#d0d0d0",
  unknown = "#c7c7c7"
)


#! etc

ver <- "v 4.2.2"


test_results_files <- c(
  file.path("..", "tests", "test-results.csv"),
  file.path("tests", "test-results.csv")
)
test_results_file <- test_results_files[file.exists(test_results_files)][1]

app_test_status <- list(
  text = "Tests unavailable",
  badge = "unknown",
  badge_color = "warning",
  icon = "circle-question",
  icon_color = "#e8c468"
)

if (length(test_results_file) && !is.na(test_results_file)) {
  test_results <- try(read.csv(test_results_file), silent = TRUE)

  if (
    !inherits(test_results, "try-error") &&
      nrow(test_results) > 0 &&
      all(c("passed", "failed") %in% names(test_results)) &&
      is.finite(test_results$passed[1]) &&
      is.finite(test_results$failed[1])
  ) {
    tests_passed <- test_results$passed[1]
    tests_failed <- test_results$failed[1]
    tests_ok <- tests_failed == 0

    app_test_status <- list(
      text = as.character(glue("{tests_passed} tests passed")),
      badge = as.character(glue("{tests_failed} failed")),
      badge_color = if (tests_ok) "success" else "danger",
      icon = if (tests_ok) "circle-check" else "circle-xmark",
      icon_color = if (tests_ok) "#00815f" else "#d70427"
    )
  }
}
