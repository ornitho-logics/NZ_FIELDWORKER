test_that("main server initializes and updates the reference date", {
  app <- load_main_app()
  today <- as.Date(Sys.time(), tz = app$env$preferred_timezone)
  saved <- new.env(parent = emptyenv())
  saved$date <- as.Date(NA)
  saved$notices <- character()

  app$env$get_reference_date <- function() today
  app$env$dbtable_is_updated <- function(...) "unchanged"
  app$env$set_reference_date <- function(refdate) {
    saved$date <- as.Date(refdate)
    TRUE
  }
  app$env$WarnToast <- function(message) {
    saved$notices <- c(saved$notices, as.character(message))
  }
  app$env$ErrToast <- function(...) NULL
  app$env$TABLE_show <- function(...) shiny::renderText("")
  app$env$later <- function(callback, delay = 0) callback()

  shiny::testServer(app$server, {
    session$flushReact()

    expect_identical(as.Date(reference_date()), today)
    expect_identical(as.Date(active_refdate()), today)
    expect_match(output$ref_date_text$html, as.character(today), fixed = TRUE)
    expect_match(output$open_gps$html, "../gpxui/", fixed = TRUE)
    expect_match(output$open_db$html, "db_ui/field_db.php", fixed = TRUE)

    next_date <- today + 1
    session$setInputs(refdate = as.character(next_date), set_refdate = 1)
    session$flushReact()

    expect_identical(saved$date, next_date)
    expect_identical(as.Date(reference_date()), next_date)
    expect_true(any(grepl(
      as.character(next_date),
      saved$notices,
      fixed = TRUE
    )))
  })
})
