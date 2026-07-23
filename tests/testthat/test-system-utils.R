test_that("showTable displays a faulty view SQL error as a table", {
  env <- new.env(parent = globalenv())
  env$data.table <- data.table::data.table
  env$glue <- glue::glue
  env$glue_collapse <- glue::glue_collapse

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0

  env$db_get <- function(sql) {
    calls$n <- calls$n + 1

    if (calls$n == 1) {
      return(data.frame(Field = "value"))
    }

    stop("View 'BROKEN_VIEW' references an invalid table", call. = FALSE)
  }
  env$DBq <- function(...) {
    stop("DBq should not be called", call. = FALSE)
  }

  result <- env$showTable("BROKEN_VIEW")

  expect_s3_class(result, "data.table")
  expect_named(result, "error")
  expect_identical(
    result$error,
    "View 'BROKEN_VIEW' references an invalid table"
  )
  expect_identical(calls$n, 3)
})


test_that("showTable displays a column lookup error and view DDL", {
  env <- new.env(parent = globalenv())
  env$data.table <- data.table::data.table
  env$glue <- glue::glue
  env$htmlEscape <- htmltools::htmlEscape

  source_app_file(app_file("main", "R", "system_utils.R"), env)

  env$db_get <- function(sql) {
    if (startsWith(sql, "SHOW CREATE VIEW")) {
      return(
        data.frame(
          View = "BROKEN_VIEW",
          `Create View` = "CREATE VIEW BROKEN_VIEW AS SELECT n FROM missing WHERE n < 1",
          check.names = FALSE
        )
      )
    }

    stop("Invalid view definition", call. = FALSE)
  }

  result <- env$showTable("BROKEN_VIEW")

  expect_s3_class(result, "data.table")
  expect_named(result, c("error", "ddl"))
  expect_identical(result$error, "Invalid view definition")
  expect_identical(
    result$ddl,
    "CREATE VIEW BROKEN_VIEW AS SELECT n FROM missing WHERE n &lt; 1"
  )
})
