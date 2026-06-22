#' shiny::runApp("./DataEntry/RESIGHTINGS_PUBLIC", launch.browser = TRUE)

require(DataEntry)


table_name <- "RESIGHTINGS_PUBLIC"

group <- "nz_fieldworker"

exclude_columns <- c("pk", "nov")

n_empty_lines <- 10

prefilled <- list(
  species = "BADO"
)

dropdowns <- list(
  species = c("BADO", "WRYB", "SNZD", "BFDO"),
  sex = c("M", "M?", "F", "F?", "U"),
  country = c("NZ", "AU", "O"),
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
  falcon_upload = c("0", "1")
)
