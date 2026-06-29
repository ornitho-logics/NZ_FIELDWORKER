#' shiny::runApp("./DataEntry/EGGS", launch.browser = TRUE)

require(DataEntry)

table_name <- "EGGS"

group <- "nz_fieldworker"

exclude_columns <- c("pk", "nov")

n_empty_lines <- 20

observers <-
  db_get("SELECT COALESCE( (SELECT observer FROM OBSERVERS), '??') AS o;")$o


prefilled <- list(
  date = format(Sys.Date(), "%Y-%m-%d"),
  species = "BADO",
  observer = observers,
  site = "CR"
)


dropdowns <- list(
  species = c("BADO", "WRYB", "SNZD", "BFDO"),
  egg_id = as.character(1:4),
  float_location = c("bottom", "suspended", "surface"),
  observer = observers
)
