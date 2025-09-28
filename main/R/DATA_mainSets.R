

select_combo_list <- function() {
  DBq("SELECT DISTINCT UL, LL, UR, LR FROM CAPTURES where tagID is not NULL") |>
    make_combo()
}

#' x = all_adults()
all_adults <- function() {

  mn = dbq(q = 
    glue("SELECT UL, LL, UR, LR, ring, nest_id, date, field_sex,site_code site, latitude lat, longitude lon, tag_id FROM
          BADOatNZ.CAPTURES
        WHERE age <>'J' ")
  )

  ar = DBq(
    glue("SELECT UL, LL, UR, LR, ring, nest_id, date, field_sex,site, lat, lon, tag_id
    FROM CAPTURES_ARCHIVE
      WHERE age <>'J' ")
  )
    
  ac = DBq(glue("
    SELECT UL, LL, UR, LR, ring, nest_id, date, field_sex, site, lat, lon, tag_id FROM
        CAPTURES_active
          WHERE age <>'J' "))

  o = list(mn, ac, ar) |> rbindlist()

  make_combo(o)

  o[, let(UL = NULL, LL = NULL, UR = NULL, LR = NULL)]
  setcolorder(o, "combo")
  o[combo == '*/*|*/*', combo := NA]

  o[, info_label := paste(date, field_sex, site, collapse = "<br>", sep = "<br>"), by = .I]

  o

}

all_adults_sf <- function(x) {
  
  o = x[!is.na(lat)]
  o[, i := .I]
  o[, map_txt   := glue_data(.SD, '<div class="bdot-info"><div class="title">{combo}</div></div>')]
  o[, map_popup := glue_data(.SD, 'site:{site}<br>date:{date}<br>sex:{field_sex}<br>tag:{tag_id}<br>nest:{nest_id}') ]
  

  st_as_sf(o, coords = c("lon", "lat"), crs = "OGC:CRS84")  

}

#' x = all_adults() |> pairs()
pairs <- function(x) {


  o = x[!is.na(nest_id) & !nest_id == 'Kaik' & field_sex %in% c("M", "F")]
  o[, n := .N, nest_id]
  o = o[n > 1]


  dcast(
  o,
  site+nest_id + lat + lon  ~ field_sex  ,
  value.var =   "combo",
  fun.aggregate = \(x) paste(unique(x), collapse = "; ")
  )

  

}
