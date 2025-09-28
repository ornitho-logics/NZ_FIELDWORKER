
# TODO: 
  # at found GPS AND POint are required
  # negative validation: no GPS or POINT for revisits. 


#' source("./DataEntry/NESTS/global.R")
#' source("./DataEntry/NESTS/inspector.R")
#'
#' dat = DBq('SELECT * FROM NESTS')
#' dat = DBq('SELECT * FROM FIELD_2024_BADOatNZ.NESTS')
#' class(dat) = c(class(dat), 'NESTS')
#' ii = inspector(dat)
#' evalidators(ii)



inspector.NESTS <- function(dat, ...){  

x <- copy(dat)
x[, rowid := .I]


list(

# Mandatory values
  x[, .( observer, nest_id, nest_state,clutch_size, rowid)] |>
    is.na_validator() |>
    try_validator(nam = "required")
,

# Reinforce values (from given lists)
  {
  z = x[, .(
    species,
    site,
    nest_state, 
    behav,
    rowid
  )]

  v = data.table(
    variable = names(z)[-which(names(z)=='rowid')],
    set = c(
      list(c("BADO", "WRYB", "SNZD", "BFDO", "OTHER")), # species
      list(c("AU","CH","CR","HC","HR","KK","KP","KT","MB","MR","MS","OD","OK","OM","PB","PR","TA","TO","TP","TR","TS","WA")),  #site
      list(c("I", "P", "D", "H", "B", "O")), # nest_state
      list(c("IN", "CO", "PR", "BW", "BC", "NM", "FC", "FA", "RS", "LF", "AT", "FT", "OB")) # behav
    )
  )

  is.element_validator(z, v)
  } |> try_validator(nam = "from list")
,

# Date
  x[, .(date, rowid)]   |>
    POSIXct_validator() |>
    try_validator(nam = "date")
,  

# Times  
  x[, .(time_visit, rowid)] |>
    hhmm_validator() |>
    try_validator(nam = "time")
,

# Observers
  x[, .(observer, rowid)] |>
  is.element_validator(v = data.table(
      variable = "observer",
      set      = list(DBq("SELECT observer ii FROM OBSERVERS")$ii) ), 
      reason   = 'entry not in the OBSERVERS table' ) |> 
      try_validator(nam = "observer")
,

# Nest_ID pattern
  x[, .(nest_id, rowid)] |>
  is.regexp_validator(regexp = "^-?(BA|WR|SN|BF)(0[1-9]|1[0-1])(0[1-9]|[1-9][0-9])$") |>
  try_validator(nam = "nest id")

,

# color bands
  x[, .(female_UL,female_UR,male_UL,male_UR, rowid)] |>
  is.regexp_validator(regexp = "^[XOYWBRGLM]$|^F[A-Z][ACEHJKLMPNTUVXY1234567890]{2}$") |>
  try_validator(nam = "combo f")
  ,
  x[, .(female_LL,female_UR,male_LL,male_LR, rowid)] |>
  is.regexp_validator(regexp = "^[XOYWBRGLM]$") |>
  try_validator(nam = "combo m")
,

# ring pattern
  x[, .(female_ring, male_ring, rowid)] |>
  is.regexp_validator(regexp = "C(P?[0-9]{5})$") |>
  try_validator(nam = "ring")




)}