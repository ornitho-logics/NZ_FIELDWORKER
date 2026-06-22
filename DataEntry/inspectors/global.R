#' shiny::runApp("./DataEntry/Inspector", launch.browser = TRUE )

require(DataEntry)

table_name <- "inspectors"

group <- "nz_fieldworker"

backupdir <- "~/nz_fieldworker_2026_bk"

n_empty_lines <- 2

exclude_columns <- "updated_at"

code_column <- "inspector"

code_column_width <- 760

code_row_height <- 100
