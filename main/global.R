#+ NOTE:
#' list.files('./R', full.names = TRUE) |> lapply(source) |> invisible(); source('global.R')
#' ss = function() shiny::runApp(launch.browser = TRUE)

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


dbtabs_view <- c(
  "OBSERVERS",
  "CAPTURES",
  "CAPTURES_active",
  "CAPTURES_ARCHIVE",
  "NESTS",
  "EGGS",
  "RESIGHTINGS",
  "RESIGHTINGS_PUBLIC",
  "GPS_POINTS",
  "GPS_TRACKS"
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
options(dbo.tz = "Pacific/Auckland")
options(ggrepel.max.overlaps = Inf)


#! UI DEFAULTS

ver <- "v 3.0"
pagetitle <- "Banded dotterel"
set_capturedDaysAgo <- 3
set_seenDaysAgo <- 3
