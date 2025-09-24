

select_combo_list <- function() {
  DBq("SELECT DISTINCT UL, LL, UR, LR FROM CAPTURES where tagID is not NULL") |>
    make_combo(short = "LR")
}

#' x = all_captures()
all_captures <- function() {

  ar = DBq("SELECT * FROM CAPTURES_ARCHIVE")
  ac = DBq("SELECT * FROM CAPTURES_active")

  o = rbind(ac, ar)

  o[, map_label := make_combo(.SD)]

}
