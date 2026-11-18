#+ NOTE:
#' list.files('./main/R/', full.names = TRUE) |> lapply(source) |> invisible(); source('main/global.R')
#' shiny::devmode(TRUE);shiny::runApp("./main", launch.browser = TRUE )

# App release version: major.minor.patch. Bump patch for fixes, minor for
# features, and major for incompatible changes when preparing a release.
app_version <- "1.0.0"

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
    "mgcv",
    "ggrepel",
    "htmltools",
    "htmlwidgets",
    "ini",
    "jsonlite",
    "quarto",
    "patchwork",
    "png",
    "curl",
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
  "RESIGHTINGS_field",
  "RESIGHTINGS_PUBLIC",
  "GPS_POINTS",
  "settings",
  "predict_hatching"
)


dbtabs_show_views <- c(
  "TODO_LIST",
  "AVAILABLE_COMBOS",
  "NESTS_LATEST",
  "CAPTURES_ARCHIVE",
  "EGGS_HATCH_PREDICTION",
  "OVERVIEW"
)

# watch list for View updates
dbtabs_show_view_sources <- list(
  OVERVIEW = c(
    "settings",
    "CAPTURES",
    "NESTS",
    "EGGS",
    "RESIGHTINGS"
  ),

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
    "predict_hatching",
    "RESIGHTINGS"
  ),
  BROODS_LATEST = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching",
    "RESIGHTINGS"
  ),
  LIVE_NEST_MAP = c(
    "settings",
    "NESTS",
    "GPS_POINTS",
    "CAPTURES",
    "EGGS",
    "predict_hatching",
    "RESIGHTINGS",
    "TODO_REFRESH_STATUS",
    "TODO_PARENT_STATUS_SNAPSHOT"
  ),
  CAPTURES_ARCHIVE = c("BADOatNZ.CAPTURES"),

  EGGS_HATCH_PREDICTION = c(
    "settings",
    "NESTS",
    "EGGS",
    "predict_hatching"
  )
)


nest_state_cols <- c(
  "S" = "#f38c38",
  "F" = "#00815f",
  "I" = "#fff023",
  "brood" = "#1aa9fc",
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


# Installed-app update detection uses a separate content hash.
read_pwa_build = function(app_dir = getwd()) {
  path = file.path(app_dir, "www", "build.json")
  if (!file.exists(path)) return(NULL)
  build = tryCatch(
    jsonlite::read_json(path),
    error = function(error) NULL
  )
  if (!is.list(build) || !is.character(build$id) || length(build$id) != 1L ||
      is.na(build$id) || !grepl("^[a-f0-9]{64}$", build$id)) {
    return(NULL)
  }
  build
}


resolve_pwa_build_id <- function(app_dir = getwd()) {
  build <- read_pwa_build(app_dir)
  if (is.null(build)) return("unknown")
  build$id
}


# Snapshot once: changed static files must not relabel an older R process.
pwa_build_id <- resolve_pwa_build_id()
