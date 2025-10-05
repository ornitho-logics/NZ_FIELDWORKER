#' source("./DataEntry/RESIGHTINGS/global.R")
#' source("./DataEntry/RESIGHTINGS/inspector.R")
#'
#' dat = DBq('SELECT * FROM RESIGHTINGS')
#' class(dat) = c(class(dat), 'RESIGHTINGS')
#' ii = inspector(dat)
#' evalidators(ii)



inspector.RESIGHTINGS <- function(dat, ...){

x <- copy(dat)
x[, rowid := .I]

list(
# Mandatory values
x[, .(species, observer, gps_id, gps_point,behav, rowid)] |>
  is.na_validator() |>
  try_validator(nam = "required")
,

# Reinforce values (from given lists)
{
z = x[, .(
  species,
  behav,
  rowid
)]

v = data.table(
  variable = names(z)[-which(names(z)=='rowid')],
  set = c(
    list(c("BADO", "WRYB", "SNZD", "BFDO", "OTHER")), # species
    list(c("IN", "CO", "PR", "BW", "BC", "NM", "FC", "FA", "RS", "LF", "AT", "FT", "OB")) # behav
  )
)

is.element_validator(z, v)
} |> try_validator(nam = "given")
,


# Color bands
x[, .(UL, UR, rowid)] |>
  is.regexp_validator(regexp = "^[XM]$|^FW[ACEHJKLMPNTUVXY1234567890]{2}$") |>
  try_validator(nam = "upper combo")
,
x[, .(LL, LR, rowid)] |>
  is.regexp_validator(regexp = "^[XOYWBRGL]{1,2}$") |>
  try_validator(nam = "lower combo")







)

}
