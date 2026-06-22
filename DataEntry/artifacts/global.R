#' shiny::runApp("../DataEntry/artifacts", launch.browser = TRUE )

require(DataEntry)

table_name <- "artifacts"

group <- "nz_fieldworker"

backupdir <- "~/nz_fieldworker_2026_bk"

n_empty_lines <- 2

exclude_columns <- "updated_at"

code_column <- "artifact"

code_column_width <- 760

code_row_height <- 100
