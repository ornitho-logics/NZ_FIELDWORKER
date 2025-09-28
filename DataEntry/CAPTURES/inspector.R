
#TODO-s: 
  # update time_order_validator to work with hmn class
  # if capture_status = R but combo in 2024 then do everything
  # update time_order_validator to work with hmn class
  # color bands  validate combos not individual UL, LL

#' source("./DataEntry/CAPTURES/global.R")
#' source("./DataEntry/CAPTURES/inspector.R")
#' 
#' dat = DBq('SELECT * FROM CAPTURES')
#' # dat = DBq('SELECT * FROM FIELD_2024_BADOatNZ.CAPTURES')
#' class(dat) = c(class(dat), 'CAPTURES')
#' ii = inspector(dat)
#' evalidators(ii)



inspector.CAPTURES <- function(dat, ...) {

x = copy(dat)
x[ , rowid := .I]

list(
# Mandatory values
  x[, .(species, site, date, caught, nest_id, book_id, form_id, observer, ring, capture_status, rowid)] |>
    is.na_validator() |>
    try_validator(nam = "mandatory")
,
# Reinforce values within given intervals 
  x[, .(book_id,form_id,gps_id,gps_point, rowid)] |>
  interval_validator(
    v = fread("    
        variable   lq     uq
          book_id   1      5  
          form_id   101    599
            gps_id  1      11
          gps_point 1      999"),
    reason = "Out of range value."
  )|> try_validator(nam = "constrain interval")
,
# Reinforce values (from given lists)
  {
  z = x[, .(
    species,
    site,
    capture_method,
    book_id,
    gps_id,
    field_sex,
    age,
    tag_action,
    tag_type,
    capture_status,
    parents,
    rowid
  )]

  v = data.table(
    variable = names(z)[-which(names(z)=='rowid')],
    set = c(
      list(c("BADO", "WRYB", "SNZD", "BFDO", "OTHER")), # species
      list(c("AU","CH","CR","HC","HR","KK","KP","KT","MB","MR","MS","OD","OK","OM","PB","PR","TA","TO","TP","TR","TS","WA")),#site
      list(c("HA", "TB", "TN", "SM", "MM", "O")), #capture_method
      list(1:6) ,#book_id
      list(1:10), #gps_id
      list(c("M", "F", "U")), # field_sex
      list(c("A", "J")), # age
      list(c("O", "D", "R", "S", "N")), # tag_action
      list(c("PTT", "GPS")), # tag_type
      list(c("F", "R", "C", "D")), # capture_status
      list(c("MF","F" ,"M" ,"U1","U2","O")) # parents
    )
  )

  is.element_validator(z, v)
  } |> try_validator(nam = "constrain value")
,
# Reinforce values (from existing db tables: OBSERVERS)
  x[, .(observer, rowid)] |>
  is.element_validator(v = data.table(
      variable = "observer",
      set      = list(DBq("SELECT observer ii FROM OBSERVERS")$ii) ), 
      reason   = 'entry not in the OBSERVERS table' ) |> 
      try_validator(nam = "has to exist in a table")
,
# Interval: Validate PTT tags
  x[tag_type == "PTT", .(tag_id, rowid)] |>
    interval_validator(
      v = data.frame(variable = 'tag_id',  lq = 266372, uq = 266471),
      reason = "Wrong ID, It should be > 266371 and < 266472"
    )|> try_validator(nam = 'ptt values')
,
# Date
  x[, .(date, rowid)]   |>
    POSIXct_validator() |>
    try_validator(nam = 5)
,  
# Times  
  x[, .(cap_start,caught,released, rowid)] |>
    hhmm_validator() |>
    try_validator(nam = 6)
,
# Nest_ID pattern
  x[, .(nest_id, rowid)] |>
  is.regexp_validator(regexp = "^-?(BA|WR|SN|BF)(0[1-9]|1[0-1])(0[1-9]|[1-9][0-9])$") |>
  try_validator(nam = 7)

,
# ring pattern
  x[, .(ring, rowid)] |>
  is.regexp_validator(regexp = "C(P?[0-9]{5})$") |>
  try_validator(nam = 8)
,
# Required (capture_status == "F" & age == "A")
  x[capture_status == "F" & age == "A", 
    .(gps_id, gps_point,field_sex,
    UL,UR,LL,LR,
    culmen, tarsus,total_head,head_white,head_black,rufous_band,wing,
    rowid)] |>
    is.na_validator("Required at first capture.") |>
    try_validator(nam = 9)
,
# Values should be UNIQUE within their containing table (capture_status == "F" & ring)
  x[capture_status == "F" & !is.na(ring), .(ring, rowid)] |>
  is.duplicate_validator(
    v = data.table(
      variable = "ring",
      set = list(DBq("SELECT distinct ring FROM CAPTURES_ARCHIVE")$ID)
      ),
    reason = "Metal band already in use! Is this a recapture?"
  ) |> try_validator(nam = "double ring")
,
# Values should be UNIQUE within their containing table (capture_status == "F" & combo)
  { 
  z = x[capture_status == "F", .(UL, LL, UR, LR, rowid)]
  z[, combo := make_combo(.SD)]
  is.duplicate_validator(z,
    v = data.table(
      variable = "combo",
      set = list(DBq("SELECT distinct UL,LL, UR, LR FROM CAPTURES_ARCHIVE") |> make_combo())
      ),
    reason = "combo already in use! Is this a recapture?"
  ) |> try_validator(nam = "double combo")

  }
,
# morphometrics (capture_status == "F")
  x[capture_status == "F" & age == "A", .(culmen, tarsus, wing, weight, rowid)] |>
  interval_validator(
    v = fread("    
        variable   lq     uq
          culmen   15.8   19.3  
          tarsus   27.1   32.3
            wing   125    139
          weight   52.6   69.0"),
    reason = "Measurement out of the typical range."
  )|> try_validator(nam = "measurements Adults")
,
# morphometrics( capture_status == "F" & age == "J")
  x[capture_status == "F" & age == "J", .(culmen,  tarsus,  weight, rowid)] |>
  interval_validator(
    v = fread("    
        variable   lq     uq
          culmen   6.89   19.3  
          tarsus   18.8   32.3
          weight   6.68   69.0"),
    reason = "Measurement out of the typical range."
  )|> try_validator(nam = "measurements Juvenniles")









)


}
