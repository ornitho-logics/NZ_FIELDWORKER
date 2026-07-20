#' shiny::runApp("./DataEntry/spatial_objects", launch.browser = TRUE)

require(DataEntry)

table_name <- "spatial_objects"
group <- "nz_fieldworker"

backupdir <- "~/nz_fieldworker_2026_bk"
n_empty_lines <- 2

code_column <- "value"

id_column <- "variable"

code_column_width <- 760

code_row_height <- 100
