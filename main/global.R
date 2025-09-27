#+ NOTE:
  #' list.files('./main/R', full.names = TRUE) |> lapply(source) |> invisible(); source('./main/global.R')
  #' ss = function() shiny::runApp('main', launch.browser = TRUE)


#! PACKAGES & DATA
  sapply(
    c(
    "dbo",           # remotes::install_github('mpio-be/dbo')
    "sf",
    "data.table",
    "stringr",
    "forcats",
    "zip",
    "glue",
    "ggplot2",
    "ggrepel",
    "patchwork",
    
    "waiter",
    "shinyWidgets",
    "shinycssloaders",
    "bs4Dash",
    "DT",
    
    "leaflet",
    "leafem",
    "leaflet.extras"
  ), require, character.only = TRUE, quietly = TRUE)




#! OPTIONS
    app_nam              = "NZ_FIELDWORKER"
    server               = "nz_fieldworker"
    db                   = "FIELD_2025_BADOatNZ"
    dbtabs_entry         = c("OBSERVERS", "CAPTURES", "NESTS", "EGGS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC")
    dbtabs_view          = c("OBSERVERS", "CAPTURES",  "NESTS", "EGGS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC")
    species              = "BADO"
    ggrepel.max.overlaps = 20

  options(shiny.autoreload = TRUE)

  options(dbo.tz = "Pacific/Auckland")



#! UI DEFAULTS
  
  ver                 = "v 2.0"
  apptitle            = "Aotearoa"
  pagetitle           = "Banded dotterel"
  set_capturedDaysAgo = 3
  set_seenDaysAgo     = 3

 
