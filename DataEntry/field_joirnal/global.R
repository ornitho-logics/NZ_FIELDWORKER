#' shiny::runApp("./DataEntry/field_joirnal", launch.browser = TRUE)

library(shiny)

table_name <- "field_joirnal"
group <- "nz_fieldworker"
journal_photo_limit <- 65535L

journal_today <- function() {
  as.Date(format(Sys.time(), tz = "Pacific/Auckland", format = "%Y-%m-%d"))
}

journal_save <- function(date, observer, entry, photo = NULL) {
  con <- DataEntry::db_con(group = group)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbExecute(
    con,
    paste("INSERT INTO `field_joirnal` (`date`, `observer`, `entry`, `photo`)",
          "VALUES (?, ?, ?, ?)"),
    params = list(as.character(date), observer, entry, list(photo))
  )
  invisible(TRUE)
}
