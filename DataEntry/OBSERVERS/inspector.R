
#' source("./DataEntry/OBSERVERS/global.R")
#' source("./DataEntry/OBSERVERS/inspector.R")
#' 
#' dat = DBq('SELECT * FROM OBSERVERS')
#' class(dat) = c(class(dat), 'OBSERVERS')
#' ii = inspector(dat)
#' evalidators(ii)


inspector.OBSERVERS <- function(dat, ...) {

x = copy(dat)
x[ , rowid := .I]

list(
  # Mandatory values
  x[, .( observer, rowid)] |>
    is.na_validator() |>
    try_validator(nam = "mandatory"),

  x[, .(name, rowid)] |>
    is.na_validator() |>
    try_validator(nam = "mandatory")




)


}
