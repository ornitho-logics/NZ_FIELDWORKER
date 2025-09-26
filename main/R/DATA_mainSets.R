

select_combo_list <- function() {
  DBq("SELECT DISTINCT UL, LL, UR, LR FROM CAPTURES where tagID is not NULL") |>
    make_combo()
}

#' x = all_captures()
all_captures <- function() {

  cnams = c(
    "UL", "LL","UR", "LR",
    "ring", "nest_id",
    "site", "date", "field_sex",  
    "lat", "lon", 
    "tag_id"
  ) |> paste(collapse = ", ")

  ar = DBq(glue("SELECT {cnams} FROM CAPTURES_ARCHIVE where age <>'J' "))
  ac = DBq(glue("SELECT {cnams} FROM CAPTURES_active where age <>'J' "))

  o = rbind(ac, ar)

  make_combo(o)

  o


}

#' x = all_captures()
pairs <- function(x) {

  o = x[!is.na(nest_id)]
  o[, n := .N, nest_id]
  o = o[n > 1]

  dcast(
  o,
  site+nest_id + lat + lon  ~ field_sex  ,
  value.var =   "combo",
  fun.aggregate = \(x) paste(unique(x), collapse = "; ")
)

  

}
