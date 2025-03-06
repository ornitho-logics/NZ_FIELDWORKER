
#' source("./DataEntry/CAPTURES/global.R")
#' source("./DataEntry/CAPTURES/inspector.R")
#' 
#' dat = DBq('SELECT * FROM CAPTURES')
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
      try_validator(nam = 1)
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
    )|> try_validator(nam = 2)
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
      harness_size,
      rowid
    )]

    v = data.table(
      variable = names(z)[-which(names(z)=='rowid')],
      set = c(
        list(c("BADO", "WRYB", "SNZD", "BFDO", "OTHER")), # species
        list(c("MR", "PR", "KT", "HC", "MS", "MB", "OM", "CH", "TO", "KK", "TS", "TA", "EB", "CR", "TR", "TP", "HR", "OD")),#site
        list(c("HA", "TB", "TN", "SM", "MM", "O")), #capture_method
        list(1:6) ,#book_id
        list(1:10), #gps_id
        list(c("M", "F", "U")), # field_sex
        list(c("A", "J")), # age
        list(c("O", "D", "R", "S", "N")), # tag_action
        list(c("PTT", "GPS")), # tag_type
        list(c("F", "R", "C", "D")), # capture_status
        list(c("MF","F" ,"M" ,"U1","U2","O")), # parents
        list(c("AVG", "BIG", "SML")) # harness_size
      )
    )

    is.element_validator(z, v)
    } |> try_validator(nam = 3)
  ,

  # Reinforce values (from existing db tables)
    x[, .(observer, rowid)] |>
    is.element_validator(v = data.table(
        variable = "observer",
        set      = list(DBq("SELECT observer ii FROM OBSERVERS")$ii) ), 
        reason   = 'entry not in the OBSERVERS table' ) |> 
        try_validator(nam = 6)
  ,

  # Validate GPS tags
    x[tag_type == "GPS", .(tag_id, rowid)] |>
    is.element_validator(v = data.table(
    variable = "tag_id",
    set      = list(c('0621','0625','0629','062a','062b','062e','0635','0640','0641','07ec','0a65','0a8d','0a8e','0a8f','0a90','0a91','0a96','0aa0','0aa1','0aa2','0aa3','0aa6','0aa7','0ab1','0ab2','0ab3','0ab4','0ab5','0ab6','0ac1','0ac6','0ac7','0ac8','0ae0','0ae1')) ), 
    reason   = 'invalid ID.' ) |> 
    try_validator(nam = 'druid tags')
  ,

  # Validate PTT tags
    x[tag_type == "PTT", .(tag_id, rowid)] |>
      interval_validator(
        v = data.frame(variable = 'tag_id',  lq = 266372, uq = 266471),
        reason = "Wrong ID, It should be > 266371 and < 266472"
      )|> try_validator(nam = 'ptt')
  ,

  # Date
    x[, .(date, rowid)]   |>
      POSIXct_validator() |>
      try_validator(nam = 4)
  ,  

  # Times  
    x[, .(cap_start,caught,released, rowid)] |>
      hhmm_validator() |>
      try_validator(nam = 5)
  ,

  # # Time order #TODO: update time_order_validator to work with hmn class
    #   x[, .(cap_start,caught, rowid)] |>
    #   time_order_validator(time1 = 'cap_start', time2 = 'caught')   |>
    #   try_validator(nam = 7)
    #   ,
    #   x[, .(caught,released, rowid)] |>
    #   time_order_validator(time1 = 'caught', time2 = 'released')   |>
    #   try_validator(nam = 8)
    # ,

  # Nest_ID pattern
    x[, .(nest_id, rowid)] |>
    is.regexp_validator(regexp = "^-?(BA|WR|SN|BF)(0[1-9]|1[0-1])(0[1-9]|[1-9][0-9])$") |>
    try_validator(nam = 9)

  ,

  # ring pattern
    x[, .(ring, rowid)] |>
    is.regexp_validator(regexp = "C(P?[0-9]{5})$") |>
    try_validator(nam = 10)
  ,

  # color bands
    x[, .(UL,UR, rowid)] |>
    is.regexp_validator(regexp = "^[XOYWBRGLM]$|^F[A-Z][ACEHJKLMPNTUVXY1234567890]{2}$") |>
    try_validator(nam = 11)
    ,
    x[, .(LL,LR, rowid)] |>
    is.regexp_validator(regexp = "^[XOYWBRGLM]$") |>
    try_validator(nam = 12)
  ,

  # Required (capture_status == "F" & age == "A")
    x[capture_status == "F" & age == "A", 
      .(gps_id, gps_point,field_sex,
      UL,UR,LL,LR,
      culmen, tarsus,total_head,head_white,head_black,rufous_band,wing,
      rowid)] |>
      is.na_validator("Required at first capture.") |>
      try_validator(nam = 13)
  ,

  # Values should be UNIQUE within their containing table (capture_status == "F")
    x[capture_status == "F" & !is.na(ring), .(ring, rowid)] |>
    is.duplicate_validator(
      v = data.table(
        variable = "ring",
        set = list(DBq("SELECT distinct ring FROM CAPTURES")$ID)
        ),
      reason = "Metal band already in use! Is this a recapture?"
    ) |> try_validator(nam = 14)
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
    )|> try_validator(nam = 15)
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
    )|> try_validator(nam = 16)
  








)


}
