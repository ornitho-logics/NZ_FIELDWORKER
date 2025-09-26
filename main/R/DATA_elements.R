



make_combo <- function(d) {
  

  d[, combo := glue_data(.SD, "{UL}/{LL}|{UR}/{LR}", .na = "·")]
  d[, combo := str_remove(combo, "\\,")]


}
