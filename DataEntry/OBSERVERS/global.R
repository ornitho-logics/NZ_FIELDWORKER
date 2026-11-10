#' shiny::runApp("./DataEntry/OBSERVERS", launch.browser = TRUE )

require(DataEntry)
require(data.table)
require(stringr)

table_name <- "OBSERVERS"

group <- "nz_fieldworker"

backupdir <- "~/nz_fieldworker_2026_bk"

n_empty_lines <- 5
