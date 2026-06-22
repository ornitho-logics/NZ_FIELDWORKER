#' shiny::runApp("./DataEntry/NESTS", launch.browser = TRUE)

require(DataEntry)


table_name <- "NESTS"

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
  species = "BADO",
  site = "CR"
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
  nest_state = c("F", "I", "H", "B", "pP", "pD", "P", "D", "notA", "O"),
  bird_inc = c("M", "F", "U", "E")
)

if (length(observer_opts) > 1) {
  dropdowns$observer <- observer_opts
}
