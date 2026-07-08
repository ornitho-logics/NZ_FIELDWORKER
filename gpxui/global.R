# UI for fetching, visualizing and exporting GPS data
#' shiny::devmode(TRUE);shiny::runApp('./gpxui', launch.browser =  TRUE)

#! Packages, functions
require(gpxui)

#! Options
options(shiny.maxRequestSize = 10 * 1024^4)

#* Variables
GPS_IDS <- 1:15
cnf_path <- Sys.getenv("GPXUI_CNF")
group <- "nz_fieldworker"
