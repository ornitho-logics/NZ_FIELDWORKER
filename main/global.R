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
    
    "shinyWidgets",
    "bs4Dash",
    "DT",
    
    "leaflet",
    "leafem",
    "leaflet.extras"
  ), require, character.only = TRUE, quietly = TRUE)




#! OPTIONS
    app_nam              = "NZ_FIELDWORKER",
    server               = "nz_fieldworker",
    db                   = "FIELD_2024_BADOatNZ",
    dbtabs_entry         = c("OBSERVERS", "CAPTURES", "NESTS", "EGGS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC"),
    dbtabs_view          = c("OBSERVERS", "CAPTURES", "CAPTURES_ARCHIVE", "NESTS", "EGGS", "RESIGHTINGS", "RESIGHTINGS_PUBLIC"),
    species              = "BADO",
    ggrepel.max.overlaps = 20

  options(shiny.autoreload = TRUE)

  options(dbo.tz = "Pacific/Auckland")



#! UI DEFAULTS
  
  ver                 = "v 0.0.1"
  apptitle            = "Aotearoa"
  pagetitle           = "Banded dotterel"
  set_capturedDaysAgo = 3
  set_seenDaysAgo     = 3

 
