#+ NOTE:
#' list.files('./main/R/', full.names = TRUE) |> lapply(source) |> invisible(); source('main/global.R')
#'  shiny::startApp("./main", launch.browser = TRUE )

#! PACKAGES & DATA
sapply(
  c(
    "DataEntry",
    "sf",
    "data.table",
    "stringr",
    "forcats",
    "zip",
    "glue",
    "ggplot2",
    "ggrepel",
    "ggtext",
    "gt",
    "patchwork",
    "ggpubr",
    "ggbeeswarm",
    "ggeffects",
    "lubridate",
    "scales",

    "shiny",
    "waiter",
    "shinyWidgets",
    "shinycssloaders",
    "bs4Dash",
    "DT",

    "leaflet",
    "leafem",
    "leaflet.extras"
  ),
  require,
  character.only = TRUE,
  quietly = TRUE
)


#! OPTIONS
app_nam <- "NZ_FIELDWORKER"

group <- "nz_fieldworker"

db <- "FIELD_2026_BADOatNZ"
dbtabs_entry <- c(
  "OBSERVERS",
  "CAPTURES",
  "NESTS",
  "EGGS",
  "RESIGHTINGS",
  "RESIGHTINGS_PUBLIC",
  "inspectors",
  "artifacts"
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


species <- "BADO"


hatch_pred_gam <- "./data/gam_float_to_hach.rds"

nest_state_cols <- c(
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

todo_cols <- c(
  "catch M" = "#0745cc",
  "catch F" = "#f33b0c",
  "catch any" = "#f38c38"
)

todo_symbols <- c(
  "nest check" = 2,
  "hatch check" = 5
)

options(shiny.autoreload = TRUE)

#! UI DEFAULTS

ver <- "v 3.0"
set_capturedDaysAgo <- 3
set_seenDaysAgo <- 3
