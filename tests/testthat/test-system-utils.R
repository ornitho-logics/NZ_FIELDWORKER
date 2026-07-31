test_that("showTable directs users to the database for a faulty view", {
  env <- new.env(parent = globalenv())
  env$data.table <- data.table::data.table
  env$glue <- glue::glue
  env$glue_collapse <- glue::glue_collapse

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$db_get <- function(sql) {
    stop("View 'BROKEN_VIEW' references an invalid table", call. = FALSE)
  }

  result <- env$showTable("BROKEN_VIEW")

  expect_s3_class(result, "data.table")
  expect_named(result, "error")
  expect_identical(
    result$error,
    glue::glue(
      "Database object 'BROKEN_VIEW' is unavailable. ",
      "Open the database interface to inspect or repair it."
    )
  )
})


test_that("dbview_is_updated checks mapped source tables", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$dbtabs_show_view_sources <- list(
    MAPPED_VIEW = c("TABLE_1", "TABLE_2")
  )
  env$dbtable_is_updated <- function(tab) {
    expect_identical(tab, c("TABLE_1", "TABLE_2"))
    "source-checksum"
  }

  expect_identical(
    env$dbview_is_updated("MAPPED_VIEW"),
    glue::glue("MAPPED_VIEW:source-checksum")
  )
})


test_that("dbview_is_updated keeps unmapped views stable", {
  env <- new.env(parent = globalenv())
  env$glue <- glue::glue

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$dbtabs_show_view_sources <- list()
  env$dbtable_is_updated <- function(...) {
    stop("Unmapped views should not be checksummed", call. = FALSE)
  }

  expect_identical(
    env$dbview_is_updated("UNMAPPED_VIEW"),
    glue::glue("UNMAPPED_VIEW:unmapped")
  )
})
