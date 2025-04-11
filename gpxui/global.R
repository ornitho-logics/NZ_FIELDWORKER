
# ==========================================================================
# UI for fetching, visualizing and exporting GPS data
#     ~/github/mpio-be/gpxui/inst/Garmin65s
#' shiny::runApp('./gpxui', launch.browser =  TRUE)
# ==========================================================================

#! Packages, functions
    sapply(c( 
      "gpxui",
      "leaflet",
      "gridlayout",
      "bslib", 
      "sf",
      "dbo"
    ), require, character.only = TRUE, quietly = TRUE)


#! Options
  options(shiny.autoreload = TRUE)
  options(shiny.maxRequestSize = 10 * 1024^4)
  options(dbo.tz = "Pacific/Auckland")

#* Variables
  SERVER        = "nz_fieldworker"
  DB            = "FIELD_2024_BADOatNZ"
  GPS_IDS       = 1:15
  EXPORT_TABLES = c("nest_locations")
