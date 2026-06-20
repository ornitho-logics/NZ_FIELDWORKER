#' shiny::runApp("./DataEntry/RESIGHTINGS", launch.browser = TRUE)

require(DataEntry)


table_name <- "RESIGHTINGS"

group <- "nz_fieldworker"

exclude_columns <- c("pk", "nov")

n_empty_lines <- 10

observer_opts <-
  db_get(
    "SELECT observer FROM OBSERVERS WHERE observer IS NOT NULL AND observer <> ''"
  )[["observer"]] |>
  as.character() |>
  trimws() |>
  unique() |>
  sort()

prefilled <- list(
  date = format(Sys.Date(), "%Y-%m-%d"),
  species = "BADO"
)

if (length(observer_opts) == 1) {
  prefilled$observer <- observer_opts
}

dropdowns <- list(
  species = c("BADO", "WRYB", "SNZD", "BFDO"),
  site = c(
    "AR",
    "AU",
    "CH",
    "CL",
    "CR",
    "HC",
    "HR",
    "KK",
    "KP",
    "KT",
    "MB",
    "MR",
    "MS",
    "OD",
    "OK",
    "OM",
    "PB",
    "PR",
    "TA",
    "TO",
    "TP",
    "TR",
    "TS",
    "WA",
    "WN",
    "WS"
  ),
  rclass = c("C", "V", "R", "P", "H"),
  sex = c("M", "M?", "F", "F?", "U"),
  age = c("A", "J", "C"),
  falcon_upload = c("0", "1")
)

if (length(observer_opts) > 1) {
  dropdowns$observer <- observer_opts
}
