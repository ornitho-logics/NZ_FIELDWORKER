#' shiny::runApp("./DataEntry/CAPTURES", launch.browser = TRUE)

require(DataEntry)

table_name <- "CAPTURES"

group <- "nz_fieldworker"

exclude_columns <- c("pk", "nov")

n_empty_lines <- 10

species_opts <- c("BADO", "WRYB", "SNZD", "BFDO")

sites <- c(
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
)

observers <- prepare_for_dropdown('OBSERVERS', 'observer')


prefilled <- list(
  date = format(Sys.Date(), "%Y-%m-%d"),
  species = "BADO",
  site = "CR"
)

dropdowns <- list(
  species = species_opts,
  site = sites,
  capture_status = c("F", "R", "C", "D"),
  capture_method = c("HA", "TB", "TN", "SM", "MM", "O"),
  parents = c("MF", "F", "M", "U1", "U2", "O"),
  field_sex = c("M", "M?", "F", "F?", "U"),
  age = c("A", "J", "C"),

  brood_patch = c("0", "1"),
  wt_w_tag = c("0", "1"),
  breast_samp = c("0", "1"),
  primary_samp = c("0", "1"),
  blood_samp = c("BQ", "BF", "BE"),
  feather_wear = c("0", "1", "2", "3"),

  tag_type = c("PTT", "GPS", "GEO"),
  tag_action = c("O", "D", "R", "S", "N"),

  mugshot_photo = c("0", "1"),
  wing_photo = c("0", "1"),
  chick_tent_photo = c("0", "1"),
  chick_hide_photo = c("0", "1"),
  falcon_upload = c("0", "1"),
  observer_upload = observers
)
