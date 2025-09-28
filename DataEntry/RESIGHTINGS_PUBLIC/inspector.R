#' source("./DataEntry/RESIGHTINGS_PUBLIC/global.R")
#' source("./DataEntry/RESIGHTINGS_PUBLIC/inspector.R")
#'
#' dat = DBq('SELECT * FROM RESIGHTINGS_PUBLIC')
#' class(dat) = c(class(dat), 'RESIGHTINGS_PUBLIC')
#' ii = inspector(dat)
#' evalidators(ii)



inspector.RESIGHTINGS_PUBLIC <- function(dat, ...){

x <- copy(dat)
x[, rowid := .I]

list(
  # Mandatory values
    x[, .(species, observer, time, date, rowid)] |>
      is.na_validator() |>
      try_validator(nam = "given")
    ,

  # color bands
    x[, .(UL,UR, rowid)] |>
    is.regexp_validator(regexp = "^[XOYWBRGLM]$|^F[A-Z][ACEHJKLMPNTUVXY1234567890]{2}$") |>
    try_validator(nam = "ul,ll")
    ,
    x[, .(LL,LR, rowid)] |>
    is.regexp_validator(regexp = "^[XOYWBRGLM]$") |>
    try_validator(nam = "lr,ll")
  

)

}
